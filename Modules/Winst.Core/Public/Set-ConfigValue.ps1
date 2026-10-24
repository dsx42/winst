#Requires -Version 5.1

function Set-ConfigValue {
    <#
    .SYNOPSIS
        写入配置项：按当前值类型转换输入 → 更新内存配置 → 原子写回 config.json。
    .OUTPUTS
        [bool] 是否写入成功（输入被拒绝 / 写盘失败时为 $false，失败原因已打印）
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $current = Get-ConfigValue -Config $Context.Config -Key $Key
    $converted = ConvertTo-WinstConfigValue -Current $current -Text $Value
    if (-not $converted.Ok) {
        Write-Host ''
        Write-Host ('  输入无效：{0}，未做修改。' -f $converted.Error) -ForegroundColor Yellow
        return $false
    }

    $configPath = Join-Path $Context.DataRoot 'config.json'
    $Context.Config[$Key] = $converted.Value
    try {
        Save-WinstConfig -DataRoot $Context.DataRoot -Config $Context.Config
    } catch {
        Write-Host ''
        Write-Host ('  写入配置失败: {0}' -f $configPath) -ForegroundColor Red
        Write-Host ('  原因: {0}' -f $_.Exception.Message) -ForegroundColor DarkGray
        Write-Host '  已取消。' -ForegroundColor DarkGray
        return $false
    }
    Update-WinstContext -Context $Context

    Write-Host ''
    Write-Host ('  已保存到: {0}' -f $configPath) -ForegroundColor Green
    if ($Key -eq 'updateFilesOnly') {
        Write-Host ('  {0}: {1}' -f $DisplayName, (Format-UpdateFilesOnlyDisplay -Value $converted.Value)) -ForegroundColor Gray
    } elseif ($Key -eq 'proxyMode') {
        Write-Host ('  {0}: {1}' -f $DisplayName, (Format-ProxyModeDisplay -Value $converted.Value)) -ForegroundColor Gray
    } elseif ($converted.Value -is [bool]) {
        # 布尔项显示「开 / 关」，不显示 True / False
        Write-Host ('  {0}: {1}' -f $DisplayName, (Format-BoolDisplay -Value $converted.Value)) -ForegroundColor Gray
    } else {
        Write-Host ('  {0}: {1}' -f $DisplayName, $converted.Value) -ForegroundColor Gray
    }
    return $true
}
