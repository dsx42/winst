#Requires -Version 5.1

function Clear-WinstReplacedPackageRecord {
    <#
    .SYNOPSIS
        发布新文件前撤销同名文件的旧登记，避免中途失败后从新文件读取到旧版本或摘要。
    #>
    param([string]$PkgDir, [string]$Id, $Entry, $FilePlan, [string]$Url, [string]$IndexHash)

    $name = [string]$FilePlan['Name']
    if (@(Get-EntryArray -Entry $Entry -Key 'files') -notcontains $name) { return }
    $meta = Get-WinstFileMeta -Entry $Entry -FileName $name
    if ($IndexHash -ieq (Get-WinstRecordedHash -Entry $Entry -FileName $name) -and
            $meta.ManifestOrigin -ceq [string]$FilePlan['ManifestOrigin'] -and $meta.Url -ceq $Url) { return }

    Save-WinstCacheIndex -PkgDir $PkgDir -UpdateIds @($Id) -Update {
        param($index)
        if (-not $index.Contains($Id)) { return }
        $current = $index[$Id]
        $files = @(Get-EntryArray -Entry $current -Key 'files')
        $versionFile = Get-EntryString -Entry $current -Key 'versionFile'
        if (-not $versionFile -or $name -ieq $versionFile -or ($files.Count -and $name -ieq $files[0])) {
            $current['version'] = ''
            $current.Remove('versionFile')
            $current.Remove('versionRule')
        }
        foreach ($key in @('hashes', 'manifestHashes', 'fileMeta')) {
            $map = Get-EntryValue -Entry $current -Key $key
            if ($map) { $null = $map.Remove($name) }
        }
    }
}
