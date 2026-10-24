#Requires -Version 5.1

function Invoke-SettingChoiceItem {
    <#
    .SYNOPSIS
        设置项通用交互（选项式）：显示当前值与说明 → 列出候选项 → 输入编号选择 → 写入配置。
    .DESCRIPTION
        与 Invoke-SettingItem 的区别：不让用户手打取值，而是给出编号列表挑选（回车 / b 取消），
        选项里标出当前生效的那一项。Options 为有序数组，每项 @{ Value; Text; Note }：
        Value 是写回配置的取值（bool / int / 字符串），Text 是选项名，Note 是可选的一句说明。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Key,
        [Parameter(Mandatory = $true)][string]$DisplayName,
        [Parameter(Mandatory = $true)][string]$CurrentDisplay,
        [Parameter(Mandatory = $true)][array]$Options,
        [string]$Hint = ''
    )

    Write-Section $DisplayName
    Write-Host ('  当前值: {0}  {1}' -f $CurrentDisplay, (Get-ConfigTag -Context $Context -Key $Key)) -ForegroundColor Gray
    if ($Hint) {
        Write-Host ('  说明:   {0}' -f $Hint) -ForegroundColor DarkGray
    }
    Write-Host ''

    $current = Get-ConfigValue -Config $Context.Config -Key $Key
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $option = $Options[$i]
        Write-Host ('    {0}) {1}' -f ($i + 1), [string]$option['Text']) -NoNewline -ForegroundColor White
        if ([string]$option['Note']) {
            Write-Host ('    {0}' -f [string]$option['Note']) -NoNewline -ForegroundColor DarkGray
        }
        if (([string]$option['Value']) -ieq ([string]$current)) {
            Write-Host '  ← 当前' -NoNewline -ForegroundColor Green
        }
        Write-Host ''
    }
    Write-Host ''

    $pick = Read-WinstIndexSelection -Prompt '  请输入编号（回车 / b = 不做修改）' -Count $Options.Count -AllowEmpty
    if ($pick.Action -eq 'quit') { Set-WinstQuit; return }
    if ($pick.Action -ne 'select') {
        Write-Host '  已取消。' -ForegroundColor DarkGray
        return
    }

    $chosen = $Options[[int]$pick.Indexes[0]]
    $null = Set-ConfigValue -Context $Context -Key $Key -DisplayName $DisplayName -Value ([string]$chosen['Value'])
}
