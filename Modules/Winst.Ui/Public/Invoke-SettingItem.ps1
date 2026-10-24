#Requires -Version 5.1

function Invoke-SettingItem {
    <#
    .SYNOPSIS
        设置项通用交互：显示当前值与说明 → 读取新值 → 校验 → 调用 Set-ConfigValue。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context,
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        [Parameter(Mandatory = $true)]
        [string]$CurrentDisplay,
        [string]$Hint = '',
        [scriptblock]$Validator = $null
    )

    Write-Section $DisplayName
    Write-Host ('  当前值: {0}  {1}' -f $CurrentDisplay, (Get-ConfigTag -Context $Context -Key $Key)) -ForegroundColor Gray
    if ($Hint) {
        Write-Host ('  说明:   {0}' -f $Hint) -ForegroundColor DarkGray
    }
    Write-Host ''

    $raw = Read-Host '  请输入新值（直接回车取消）'
    if ($null -eq $raw -or -not ([string]$raw).Trim()) {
        Write-Host '  已取消。' -ForegroundColor DarkGray
        return
    }

    $value = ([string]$raw).Trim()
    if ($Validator) {
        $ok = $false
        try { $ok = [bool](& $Validator $value) } catch { $ok = $false }
        if (-not $ok) {
            Write-Host '  输入无效，未做修改。' -ForegroundColor Yellow
            return
        }
    }

    # 返回值只用于命令行退出码，菜单层不关心：显式丢弃，避免 $true/$false 漏到界面输出
    $null = Set-ConfigValue -Context $Context -Key $Key -DisplayName $DisplayName -Value $value
}
