#Requires -Version 5.1

function Write-WinstRemoteFreshnessHint {
    <#
    .SYNOPSIS
        把 Get-WinstRemoteFreshnessHint 的结论打印出来（有新包标黄 / 未变化弱化 / 无法判断中性提示）。
    #>
    param(
        [hashtable]$Context,
        [string]$PkgDir,
        [string]$Id,
        $Plan
    )

    $hint = Get-WinstRemoteFreshnessHint -Context $Context -PkgDir $PkgDir -Id $Id -Plan $Plan
    if (-not [string]$hint.Text) { return }
    $color = 'DarkYellow'
    if ([string]$hint.State -eq 'changed') { $color = 'Yellow' }
    elseif ([string]$hint.State -eq 'unchanged') { $color = 'DarkGray' }
    Write-Host ('    提示: {0}' -f [string]$hint.Text) -ForegroundColor $color
}
