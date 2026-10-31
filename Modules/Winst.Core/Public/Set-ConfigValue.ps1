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

    # 枚举型配置项（目前只有代理模式）：写错会让下游悄悄退回默认值，必须当场拒绝
    if ($Key -eq 'proxyMode') {
        $normalized = Test-WinstProxyModeValue -Value ([string]$converted.Value)
        if (-not $normalized) {
            Write-Host ''
            Write-Host ('  输入无效：代理模式只能是 auto / always / off / download-direct，未做修改。') -ForegroundColor Yellow
            return $false
        }
        $converted.Value = $normalized
    }

    # 软件安装位置只收本地路径；安装包位置可用 UNC（不带账号密码）。
    # 需要认证时必须走设置菜单——凭据要先验证再交给系统凭据管理器，这一步需要交互。
    if ($Key -eq 'installRoot') {
        $pathValue = ([string]$converted.Value).Trim().Trim('"').Trim()
        try {
            if (-not $pathValue) { throw '路径不能为空' }
            $null = Resolve-InstallRoot -DataRoot $Context.DataRoot -Options @{ InstallRoot = $pathValue } -Config $Context.Config
        } catch {
            Write-Host ''
            Write-Host ('  输入无效：{0}，未做修改。' -f $_.Exception.Message) -ForegroundColor Yellow
            return $false
        }
        $converted.Value = $pathValue
    } elseif ($Key -eq 'pkgDir') {
        $parsed = Resolve-WinstUncInput -Value ([string]$converted.Value)
        if (-not $parsed.Ok) {
            Write-Host ''
            Write-Host ('  输入无效：{0}，未做修改。' -f [string]$parsed.Error) -ForegroundColor Yellow
            if ([bool]$parsed.IsMappedDrive) {
                Write-Host '  若该共享已有映射，可在资源管理器里查看它的真实地址，再按 UNC 形式填写。' -ForegroundColor DarkGray
            }
            return $false
        }
        # 只保存解析出来的干净路径（已去掉引号、正规化 UNC）
        $converted.Value = [string]$parsed.Path
    }

    $configPath = Join-WinstPath $Context.DataRoot 'config.json'
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
