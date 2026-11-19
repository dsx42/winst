#Requires -Version 5.1

function Assert-WinstStageRecoveryClear {
    <#
    .SYNOPSIS
        持锁后检查暂存旁的恢复标记；标记里的路径仅供用户查看。
    #>
    param([Parameter(Mandatory = $true)][string]$TempDir)

    $marker = Join-WinstPath $TempDir '.winst-stage.recovery.json'
    if (-not (Test-WinstFileSystemPath -Path $marker)) { return }
    try {
        Assert-WinstSafeWritePath -Path $marker
        $record = [IO.File]::ReadAllText((ConvertTo-WinstExtendedPath -Path $marker)) | ConvertFrom-Json -ErrorAction Stop
        if (-not $record.sourceDir) { throw '缺少交付目录' }
        $detail = '交付目录：' + $record.sourceDir
    } catch {
        $detail = '无法读取标记：' + $_.Exception.Message
    }
    throw ('存在待恢复的暂存。标记：{0}；{1}。请先保存所需内容，确认后移除标记。' -f $marker, $detail)
}
