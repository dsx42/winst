#Requires -Version 5.1

function Write-WinstBundleRequirement {
    <#
    .SYNOPSIS
        ④ 打印需求清单摘要（输入条目数、收包范围及顺序）。
    #>
    param($Items, $Plan, [string]$TargetDir)

    Write-Host ''
    Write-Host ('  目标目录: {0}' -f $TargetDir) -ForegroundColor Gray
    Write-Host ('  安装清单含 {0} 项，套件共需收集 {1} 个包（含传递依赖）。' -f @($Items).Count, @($Plan).Count) -ForegroundColor Gray
    Write-Host ('  收包与套件安装清单的前三项为 {0}、{1}、winst。' -f (Get-WinstExtractEngineId), (Get-WinstDownloadEngineId)) -ForegroundColor Gray
}
