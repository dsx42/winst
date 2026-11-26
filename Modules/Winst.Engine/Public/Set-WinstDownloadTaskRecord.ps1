#Requires -Version 5.1

function Set-WinstDownloadTaskRecord {
    # 调用方持有该软件的缓存锁，每次只替换或删除一个文件的记录。
    param([string]$DestDir, [string]$FileName, $Record)

    if (-not (Test-WinstSafePathSegment -Name $FileName)) { throw '下载记录的文件名无效' }
    $records = Get-WinstDownloadTaskRecords $DestDir
    if ($null -eq $Record) {
        if (-not $records.ContainsKey($FileName)) { return }
        $records.Remove($FileName)
    } else {
        $records[$FileName] = $Record
    }
    $path = Get-WinstFluxTaskPath $DestDir
    if ($records.Count) {
        Write-FileAtomic -Path $path -Content (ConvertTo-Json @{ files = $records } -Depth 12 -Compress)
    } else {
        Remove-Item -LiteralPath $path -ErrorAction Stop
    }
}
