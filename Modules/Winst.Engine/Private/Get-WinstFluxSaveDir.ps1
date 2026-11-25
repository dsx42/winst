#Requires -Version 5.1

function Get-WinstFluxSaveDir {
    param([string]$DestDir, [string]$FileName, $Record)

    $key = Get-EntryString $Record 'workId'
    if ($key) {
        if ($key -notmatch '^[0-9a-f]{32}$') { throw 'FluxDown 恢复记录中的工作目录标识无效' }
        return Join-Path $DestDir $key
    }
    # 未记录独占目录的任务按其原始布局恢复。
    if ($Record.magnet) { return Join-Path (Join-Path (Join-Path $DestDir '.local') $FileName) 'partial' }
    return $DestDir
}
