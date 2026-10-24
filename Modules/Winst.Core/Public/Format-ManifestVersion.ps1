#Requires -Version 5.1

function Format-ManifestVersion {
    <#
    .SYNOPSIS
        格式化清单版本用于展示：空版本显示为「（无版本）」。
    #>
    param([string]$Version)
    if (-not $Version -or -not $Version.Trim()) { return '（无版本）' }
    return $Version.Trim()
}
