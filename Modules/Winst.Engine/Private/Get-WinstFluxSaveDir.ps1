#Requires -Version 5.1

function Get-WinstFluxSaveDir {
    param([string]$DestDir, [string]$FileName, $Record)

    $key = $Record['workId']
    if ($key -is [string] -and $key -match '^[0-9a-f]{32}$') {
        $dir = Join-Path $DestDir $key
    } elseif (($null -eq $key -or ''.Equals($key)) -and $Record['address'] -and $Record['computer']) {
        # 未分配独占目录的服务任务仍按提交时的保存路径核对。
        $dir = $DestDir
        if ($Record.magnet) {
            $dir = Join-Path (Join-Path (Join-Path $DestDir '.local') $FileName) 'partial'
        }
    } else { throw '下载记录中的工作目录标识无效' }
    Assert-WinstSafeWritePath -Path $dir -Directory
    return $dir
}
