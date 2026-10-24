#Requires -Version 5.1

function Write-WinstBundleRequirement {
    <#
    .SYNOPSIS
        ④ 打印需求清单摘要（软件数、引擎包、依赖项数）。
    #>
    param($Items, $Plan, [string]$TargetDir)

    Write-Host ''
    Write-Host ('  目标目录: {0}' -f $TargetDir) -ForegroundColor Gray
    Write-Host ('  安装清单里 {0} 个软件，另加两个引擎包（{1}、{2}）。' -f `
        @($Items).Count, (Get-WinstDownloadEngineId), (Get-WinstExtractEngineId)) -ForegroundColor Gray
    $depItemCount = 0
    foreach ($one in @($Plan)) { if ([string]$one['Reason'] -ceq 'dependency') { $depItemCount++ } }
    if ($depItemCount -gt 0) {
        Write-Host ('  其中 {0} 个是清单里软件的依赖（含传递依赖），也会一并收集。' -f $depItemCount) -ForegroundColor Gray
    }
}
