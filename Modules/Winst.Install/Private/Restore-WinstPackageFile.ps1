#Requires -Version 5.1

function Restore-WinstPackageFile {
    param($Context, $FilePlan, $Plan, [string]$SourceName, $Record, $DestDir, [switch]$Offline)

    $name = $FilePlan.Name
    $url = Get-EntryString $FilePlan.Decl 'url'
    $different = @{ Ok = $false; Network = $false; Action = 'Redownload'; Error = ('{0} 的来源或版本已更新。' -f $name) }
    if ($Record['mode'] -ne 'local' -and (-not $Record.ContainsKey('sourceName') -or
            -not $Record.ContainsKey('packageVersion') -or -not $Record['urlFingerprint'])) {
        # 由原服务按任务实际地址、版本及摘要核对身份，再补写记录。
        return @{ Ok = $false; Network = $false; Action = 'Continue'; Error = ('{0} 需要连接原服务核对下载任务。' -f $name) }
    }
    $version = Get-EntryString $Record 'version'
    if ((Get-EntryString $Record 'sourceName') -cne $SourceName -or
        (Get-EntryString $Record 'packageVersion') -cne [string]$Plan.version -or
        $version -cne (Get-EntryString $FilePlan.Decl 'version')) { return $different }

    $fileVersion = ''
    $main = $FilePlan.Decl -eq $Plan.download.files[0]
    if (Get-EntryValue $FilePlan.Decl 'versionOwned' -Default $main) { $fileVersion = $version }
    $hash = Get-EntryString $Record 'hash'
    $meta = @{ ExpectedHash = $hash; ChecksumFingerprint = $Record['checksumFingerprint']
        ChecksumHashFile = $Record['hashFile']; ChecksumHashFrom = $Record['hashFrom'] }
    $expected = Get-WinstExpectedHash -Context $Context -FileName $name -FileDecl $FilePlan.Decl -Offline:$Offline `
        -CachedMeta $meta -FileUrl $url -FileVersion $fileVersion
    if (-not $expected.Ok) {
        return @{ Ok = $false; Network = $expected.Network; Action = 'Continue'; Error = $expected.Error }
    }
    if ($hash -ine $expected.Hash -or
        (-not $expected.Hash -and $Record.urlFingerprint -cne (Get-WinstDownloadFingerprint -Text $url))) {
        return $different
    }
    $candidate = Get-WinstDownloadCandidate -DestDir $DestDir -FileName $name -Record $Record -Config $Context.Config
    if (-not $candidate.Ok) {
        $action = 'Continue'
        if ($Record['mode'] -eq 'local' -or $Record['rejected']) { $action = 'Redownload' }
        return @{ Ok = $false; Action = $action; Error = ('{0} 尚未就绪：{1}' -f $name, $candidate.Error); Network = $false }
    }
    $FilePlan['FileVersion'] = $fileVersion
    return (Publish-WinstPackageFile -Context $Context -FilePlan $FilePlan -Plan $Plan -SourceName $SourceName -Download $candidate `
        -Expected $expected -Url $url -DestDir $DestDir -Recover -Offline:$Offline)
}
