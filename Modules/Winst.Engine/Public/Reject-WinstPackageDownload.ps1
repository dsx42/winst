#Requires -Version 5.1

function Reject-WinstPackageDownload {
    param([hashtable]$Download, [string]$DestDir)

    if ($Download['Record']) {
        $record = $Download.Record
        $record['rejected'] = $true
        Set-WinstDownloadTaskRecord $DestDir $Download.FileName $record
        return $Download.Path
    }
    # 仅将已确认停止写入的本地下载标记为可清理。
    $failed = $Download.FailedDir
    Assert-WinstSafeWritePath -Path $failed -Directory
    $null = New-Item -ItemType Directory -Force -Path (Split-Path -Parent $failed) -ErrorAction Stop
    [IO.Directory]::Move($Download.WorkDir, $failed)
    return $failed
}
