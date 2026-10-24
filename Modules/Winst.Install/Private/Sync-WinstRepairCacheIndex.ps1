#Requires -Version 5.1

function Sync-WinstRepairCacheIndex {
    <#
    .SYNOPSIS
        ⑦ 校对安装包缓存索引 pkgDir\winst.json（缺失 / 损坏时重建，不删除任何文件）。
    .OUTPUTS
        [string] 汇总里展示的索引结论
    #>
    param([hashtable]$Context, [switch]$DryRun)

    $indexNote = '无需修复'
    if (-not (Test-Path -LiteralPath $Context.PkgDir -PathType Container)) {
        return '安装包位置不存在，已跳过'
    }

    $indexRead = Read-WinstCacheIndex -PkgDir $Context.PkgDir
    if ($indexRead.Error) { Write-Host ('    提示: {0}' -f $indexRead.Error) -ForegroundColor DarkYellow }
    if (-not $indexRead.Changed) { return $indexNote }

    if ($DryRun) { return '需要修复（预览模式未写入）' }
    try {
        Save-WinstCacheIndex -PkgDir $Context.PkgDir -Index $indexRead.Index
        return '已重建 / 校对'
    } catch {
        return ('写入失败：{0}' -f $_.Exception.Message)
    }
}
