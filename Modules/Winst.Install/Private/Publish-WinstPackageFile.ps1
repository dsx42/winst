#Requires -Version 5.1

function Publish-WinstPackageFile {
    <#
    .SYNOPSIS
        校验下载文件，保留完成记录，移动成功后交给调用方登记缓存。
    #>
    param($Context, $FilePlan, $Plan, [string]$SourceName, $Download, $Expected,
        [string]$Url, [string]$DestDir, [switch]$Recover, [switch]$Offline)

    $name = $FilePlan['Name']
    $target = $FilePlan['Target']
    $path = $Download.Path
    Assert-WinstSafeWritePath -Path $path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw ('找不到下载文件：' + $path) }
    if ([IO.Path]::GetExtension($target) -ieq '.exe' -and [IO.Path]::GetExtension($path) -ine '.exe') {
        return @{ Ok = $false; Network = $false; Action = 'Redownload'; Error = ('无法将 {0} 改名为 {1}，文件已保留。' -f (Split-Path -Leaf $path), $name) }
    }

    $check = Test-WinstFileIntegrity -FilePath $path -Expected $Expected
    $record = $Download['Record']
    $verified = Get-EntryString $record 'verified'
    if (-not $check.Ok -or ($verified -and $verified -ine $check.IndexHash)) {
        $reason = $check.Error
        if (-not $reason) { $reason = '文件与下载完成时的摘要不一致' }
        if ($Recover -and $Download['NeedsHash']) {
            return @{ Ok = $false; Network = $false; Action = 'Continue'; Error = ('{0} 未下载完成。' -f $name) }
        }
        if (-not $Recover) { $path = Reject-WinstPackageDownload -Download $Download -DestDir $DestDir }
        return @{ Ok = $false; Network = $false; Action = 'Redownload'; Error = ('{0} 校验失败：{1}。文件保留在 {2}' -f $name, $reason, $path) }
    }
    if (-not $record) {
        $record = @{ mode = 'local'; workId = (Split-Path -Leaf $Download.WorkDir); version = (Get-EntryString $FilePlan.Decl 'version')
            urlFingerprint = (Get-WinstDownloadFingerprint -Text $Url); hash = $Expected.Hash; sourceName = $SourceName; packageVersion = [string]$Plan.version }
    }
    if (-not $verified) {
        $record['actualName'] = Split-Path -Leaf $path
        $record['verified'] = $check.IndexHash
        if ($Expected.HashFile) {
            $record['hashFile'] = $Expected.HashFile
            $record['hashFrom'] = $Expected.HashFrom
            $record['checksumFingerprint'] = Get-WinstChecksumDeclarationFingerprint -FileName $name -HashFile $Expected.HashFile `
                -HashFrom $Expected.HashFrom -FileUrl $Url -FileVersion $FilePlan.FileVersion
        }
        Set-WinstDownloadTaskRecord -DestDir $DestDir -FileName $name -Record $record
    }
    $Download['FileName'] = $name
    $Download['Record'] = $record
    if (-not $Download['InPlace']) {
        try {
            Assert-WinstSafeWritePath -Path $target
            if (Test-Path -LiteralPath $target -PathType Container) { throw '目标位置已有同名目录' }
            # 5.1 的 Move-Item -Force 会先删除旧文件，源文件被占用时会丢失旧包。
            if (-not [Winst.AtomicFile]::MoveFileEx($path, $target, 1)) {
                $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
                throw (New-Object ComponentModel.Win32Exception $code)
            }
        } catch {
            return @{ Ok = $false; Network = $false; Action = 'Move'
                Error = ('{0} 已下完，移动失败：{1}。文件保留在 {2}' -f $name, $_.Exception.Message, $path) }
        }
    }
    if ($FilePlan['Url'] -cne $Url) {
        $FilePlan['CheckedAt'] = ''
        $FilePlan['ValidatorETag'] = ''
        $FilePlan['ValidatorLastModified'] = ''
    }
    if (-not $Offline -and -not $FilePlan['CheckedAt']) {
        Set-WinstFilePlanValidators -Plan $FilePlan -Context $Context -Uri $Url -RequireFields
    }
    $FilePlan['Url'] = $Url
    Set-WinstFilePlanIntegrityFromCheck -FilePlan $FilePlan -Check $check
    return @{ Ok = $true; Download = $Download }
}
