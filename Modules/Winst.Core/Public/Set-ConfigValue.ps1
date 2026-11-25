#Requires -Version 5.1

function Set-ConfigValue {
    <#
    .SYNOPSIS
        校验配置值、原子保存新副本，成功后更新运行上下文。
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
        [AllowEmptyString()]$Value,
        [switch]$Quiet
    )

    $current = Get-ConfigValue -Config $Context.Config -Key $Key
    if ($Key -eq 'fluxdownToken' -and $Value -is [securestring]) {
        try { $valueToSave = ConvertFrom-SecureString $Value -ErrorAction Stop }
        catch {
            Write-Host '  当前用户无法加密 FluxDown Token，未做修改。' -ForegroundColor Yellow
            return $false
        }
        $converted = @{ Ok = $true; Value = $valueToSave }
    } elseif ($Key -in @('proxy','fluxdownApi','fluxdownToken') -and -not $Value.Trim()) {
        $converted = @{ Ok = $true; Value = '' }
    } elseif ($Key -eq 'fluxdownToken') {
        $converted = @{ Ok = $false; Error = '请通过隐藏输入设置 FluxDown Token' }
    } elseif ($Key -eq 'fluxdownApi') {
        $address = ConvertTo-WinstFluxAddress $Value.Trim()
        $converted = @{ Ok = [bool]$address; Value = $address; Error = '地址必须是本机回环 HTTP(S) 根地址' }
    } else {
        $converted = ConvertTo-WinstConfigValue -Current $current -Text $Value
    }
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
        if (-not $pathValue) {
            Write-Host ''
            Write-Host '  输入无效：路径不能为空，未做修改。' -ForegroundColor Yellow
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
    $nextConfig = @{}
    foreach ($configKey in $Context.Config.Keys) { $nextConfig[$configKey] = $Context.Config[$configKey] }
    $nextConfig[$Key] = $converted.Value
    try {
        # 提交前构造有效上下文，避免保存后才发现路径配置不可解析。
        $nextContext = New-WinstContext -DataRoot $Context.DataRoot -Options (Get-WinstState -Name WinstOptions) -Config $nextConfig
        # 用户输入被参数或环境变量覆盖时，仍需验证实际要写入的安装路径。
        if ($Key -eq 'installRoot' -and $nextContext.InstallRootSource -ne 'config') {
            $null = Resolve-InstallRoot -DataRoot $Context.DataRoot -Options @{ InstallRoot = $pathValue }
        }
        Save-WinstConfig -DataRoot $Context.DataRoot -Config $nextConfig
    } catch {
        Write-Host ''
        Write-Host ('  写入配置失败: {0}' -f $configPath) -ForegroundColor Red
        Write-Host ('  原因: {0}' -f $_.Exception.Message) -ForegroundColor DarkGray
        Write-Host '  已取消。' -ForegroundColor DarkGray
        return $false
    }
    Update-WinstContext -Context $Context -NextContext $nextContext

    if ($Quiet) { return $true }

    Write-Host ''
    Write-Host ('  已保存到: {0}' -f $configPath) -ForegroundColor Green
    if ($Key -in @('fluxdownApi','fluxdownToken')) {
        $flux = Get-WinstFluxSettings -Config $nextConfig
        $display = if ($Key -eq 'fluxdownToken') { $flux.TokenDisplay } else { $flux.Address }
        Write-Host ('  {0}: {1}' -f $DisplayName, $display) -ForegroundColor Gray
    } elseif ($Key -eq 'updateFilesOnly') {
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
