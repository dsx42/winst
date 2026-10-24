#Requires -Version 5.1

function Select-WinstRowSource {
    <#
    .SYNOPSIS
        为一个 id 选择使用哪个软件源：命中多个来源时让用户选择（单一来源直接使用）。
    .OUTPUTS
        @{ Ok; Entry; Error; Cancelled }
    #>
    param(
        [Parameter(Mandatory = $true)]$Row,
        [switch]$AutoPick
    )

    $usable = @()
    foreach ($entry in @($Row['Sources'])) {
        if ($entry['Ok']) { $usable += $entry }
    }

    if ($usable.Count -eq 0) {
        $reason = ''
        foreach ($entry in @($Row['Sources'])) {
            if ($entry['Error']) { $reason = ('{0}（{1}）' -f $entry['Error'], [string]$entry['Source']); break }
        }
        if (-not $reason) { $reason = '软件源里没有可用的版本信息' }
        return @{ Ok = $false; Entry = $null; Error = $reason; Cancelled = $false }
    }

    if ($usable.Count -eq 1) { return @{ Ok = $true; Entry = $usable[0]; Error = ''; Cancelled = $false } }

    if ($AutoPick) {
        Write-Host ('  提示: 这个软件在 {0} 个软件源里都有定义，已使用 {1}。' -f $usable.Count, [string]$usable[0]['Source']) -ForegroundColor DarkYellow
        return @{ Ok = $true; Entry = $usable[0]; Error = ''; Cancelled = $false }
    }

    Write-Host ''
    Write-Host ('  「{0}」在多个软件源里都有，用哪个软件源装？' -f [string]$Row['Name']) -ForegroundColor Gray
    for ($i = 0; $i -lt $usable.Count; $i++) {
        $version = [string]$usable[$i]['Version']
        if (-not $version) { $version = '未知' }
        Write-Host ('    {0}) {1}    版本 {2}' -f ($i + 1), [string]$usable[$i]['Source'], $version) -ForegroundColor White
    }
    Write-Host ''
    $selection = @(Read-WinstSelection -Count $usable.Count -Single)
    if ($selection.Count -eq 0) { return @{ Ok = $false; Entry = $null; Error = ''; Cancelled = $true } }
    return @{ Ok = $true; Entry = $usable[[int]$selection[0] - 1]; Error = ''; Cancelled = $false }
}
