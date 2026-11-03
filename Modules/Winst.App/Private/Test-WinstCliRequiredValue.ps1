#Requires -Version 5.1

function Test-WinstCliRequiredValue {
    <#
    .SYNOPSIS
        统一检查已提供的 CLI 带值选项，拒绝空值或空白。
    #>
    param([string]$Name, [AllowEmptyString()][string]$Value)

    if (-not $Value.Trim()) {
        Write-Host ('  {0} 的取值不能为空。' -f $Name) -ForegroundColor Yellow
        return $false
    }
    return $true
}
