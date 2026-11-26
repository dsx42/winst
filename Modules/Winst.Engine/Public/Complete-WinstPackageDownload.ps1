#Requires -Version 5.1

function Complete-WinstPackageDownload {
    param([hashtable]$Download, [string]$DestDir)

    $path = $Download.WorkDir
    try {
        if ($path -ne $DestDir) { Clear-WinstInstallDir -Dir $path -AllowedRoot $DestDir -Strict }
        if ($Download['Record']) { Set-WinstDownloadTaskRecord $DestDir $Download.FileName $null }
    } catch { throw ('无法清理 {0}：{1}' -f $path, $_.Exception.Message) }
}
