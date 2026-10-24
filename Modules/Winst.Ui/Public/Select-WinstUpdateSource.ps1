#Requires -Version 5.1

function Select-WinstUpdateSource {
    <#
    .SYNOPSIS
        单独选择用哪个软件源更新（「单独选更新方式与软件源」的第二步）。
    .DESCRIPTION
        回车 / `b` / `q` = 不改本次来源，按默认来源规则继续更新（调用方据此回退）；
        越界 / 非数字按统一口径重新提示，不静默取消。
    .OUTPUTS
        @{ Ok; Cancelled; Source; Entry; Error }
    #>
    param($Row, [string]$OriginName = '')

    $usable = @()
    foreach ($entry in @($Row['Sources'])) {
        if ($entry['Ok']) { $usable += $entry }
    }
    if ($usable.Count -eq 0) {
        return @{ Ok = $false; Cancelled = $true; Source = ''; Entry = $null; Error = '软件源里没有可用的版本信息，无法更新' }
    }
    if ($usable.Count -eq 1) {
        return @{ Ok = $true; Cancelled = $false; Source = [string]$usable[0]['Source']; Entry = $usable[0]; Error = '' }
    }

    Write-Host ''
    Write-Host '  用哪个软件源更新？' -ForegroundColor Gray
    for ($i = 0; $i -lt $usable.Count; $i++) {
        $version = [string]$usable[$i]['Version']
        if (-not $version) { $version = '未知' }
        Write-Host ('    {0}) {1}    版本 {2}' -f ($i + 1), [string]$usable[$i]['Source'], $version) -NoNewline -ForegroundColor White
        if ($OriginName -and ([string]$usable[$i]['Source'] -ieq $OriginName)) {
            Write-Host '    ← 安装时用的软件源' -ForegroundColor DarkGray
        } else {
            Write-Host ''
        }
    }
    Write-Host ''
    $pick = Read-WinstIndexSelection -Prompt '  请输入编号（回车 / b = 不改，用默认来源更新）' -Count $usable.Count
    if ($pick.Action -eq 'quit') { Set-WinstQuit }
    if ($pick.Action -ne 'select') { return @{ Ok = $false; Cancelled = $true; Source = ''; Entry = $null; Error = '' } }

    $chosen = $usable[[int]$pick.Indexes[0]]
    return @{ Ok = $true; Cancelled = $false; Source = [string]$chosen['Source']; Entry = $chosen; Error = '' }
}
