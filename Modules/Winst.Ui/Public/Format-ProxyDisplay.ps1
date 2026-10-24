#Requires -Version 5.1

function Format-ProxyDisplay {
    param([string]$Value)

    if (-not $Value -or -not $Value.Trim()) { return '未设置' }
    return $Value.Trim()
}
