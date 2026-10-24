#Requires -Version 5.1

function Write-WinstDetailDependencies {
    <#
    .SYNOPSIS
        输出列表详情页统一的依赖区块；download 类型由依赖查询函数按业务规则忽略。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Item
    )

    $lines = @(Get-WinstDependencyLines -Context $Context -Id ([string]$Item['Id']) -Type ([string]$Item['Type']))
    if ($lines.Count -eq 0) { return }
    Write-Host '    依赖     :' -ForegroundColor Gray
    foreach ($one in $lines) {
        Write-Host ('      - {0}' -f [string]$one['Text']) -ForegroundColor ([string]$one['Color'])
    }
}
