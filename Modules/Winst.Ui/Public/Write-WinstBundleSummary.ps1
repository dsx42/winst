#Requires -Version 5.1

function Write-WinstBundleSummary {
    <#
    .SYNOPSIS
        ⑨ 汇总输出（预览 / 实际两套措辞）。
    #>
    param([string]$TargetDir, [switch]$DryRun, [int]$Copied, [int]$Skipped, [int]$MissingCount,
        [int]$ManifestCopied, [int]$ListFileCount)

    Write-Host ''
    if ($DryRun) {
        Write-Host ('  预览完成: 将复制 {0} 个软件包、跳过 {1} 个（目标已有相同版本）、缺包 {2} 个。' -f `
            $Copied, $Skipped, $MissingCount) -ForegroundColor DarkYellow
        Write-Host '  （--dry-run 不写盘；去掉该参数即可真正制作）' -ForegroundColor DarkGray
    } else {
        Write-Host ('  已生成 U 盘安装包: {0}' -f $TargetDir) -ForegroundColor Green
        Write-Host ('  软件包: 已复制 / 覆盖 {0} 个 / 跳过 {1} 个（目标已有相同版本）/ 未包含 {2} 个（缺包）' -f `
            $Copied, $Skipped, $MissingCount) -ForegroundColor Gray
        Write-Host ('  软件源清单数据: {0} 个文件；清单文件: {1} 个' -f $ManifestCopied, $ListFileCount) -ForegroundColor Gray
        Write-Host ('  启动器: {0}' -f (Join-WinstPath $TargetDir 'winst.cmd')) -ForegroundColor Gray
    }
}
