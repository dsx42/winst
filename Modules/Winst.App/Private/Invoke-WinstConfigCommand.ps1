#Requires -Version 5.1

function Invoke-WinstConfigCommand {
    <#
    .SYNOPSIS
        CLI：winst config get|set|list [<key> [<value>]]。
    .OUTPUTS
        [int] 退出码：0 成功 / 1 参数或键名问题
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string[]]$Arguments = @()
    )

    $tokens = @()
    foreach ($one in @($Arguments)) {
        $text = ([string]$one).Trim()
        if ($text) { $tokens += $text }
    }

    $sub = ''
    if ($tokens.Count -gt 0) { $sub = $tokens[0].ToLowerInvariant() }
    $key = ''
    if ($tokens.Count -gt 1) { $key = $tokens[1] }
    $value = ''
    if ($tokens.Count -gt 2) { $value = $tokens[2] }

    if (-not $sub) { $sub = 'list' }
    if (@('list', 'get', 'set') -notcontains $sub) {
        Write-WinstUnknownSubcommand -Sub $sub -Usage 'winst config get|set|list [<key> [<value>]]'
        return 1
    }

    $keys = @()
    foreach ($k in @($Context.Config.Keys)) { $keys += [string]$k }
    $keys = @($keys | Sort-Object)

    if ($sub -eq 'list') {
        Write-Section 'winst config list'
        Write-Host ''
        foreach ($one in $keys) {
            $display = [string](Get-ConfigValue -Config $Context.Config -Key $one)
            $tag = Get-ConfigTag -Context $Context -Key $one
            Write-Host ('  {0} = {1}    {2}' -f $one, $display, $tag) -ForegroundColor Gray
        }
        return 0
    }

    if (-not $key) {
        Write-Host ''
        Write-Host ('  用法: winst config {0} <key>' -f $sub) -ForegroundColor Yellow
        return 1
    }
    if ($keys -notcontains $key) {
        Write-Host ''
        Write-Host ('  没有「{0}」这个配置项。' -f $key) -ForegroundColor Yellow
        Write-Host ('  可用: {0}' -f ($keys -join '、')) -ForegroundColor DarkGray
        return 1
    }

    if ($sub -eq 'get') {
        Write-Host ''
        Write-Host ('  {0} = {1}    {2}' -f $key, [string](Get-ConfigValue -Config $Context.Config -Key $key), (Get-ConfigTag -Context $Context -Key $key)) -ForegroundColor Gray
        return 0
    }

    if ($tokens.Count -lt 3) {
        Write-Host ''
        Write-Host ('  用法: winst config set {0} <value>' -f $key) -ForegroundColor Yellow
        return 1
    }

    # Set-ConfigValue 返回写入是否成功：输入被拒绝 / 写盘失败时按参数错误退出，不打印成功文案
    if (-not (Set-ConfigValue -Context $Context -Key $key -DisplayName $key -Value $value)) {
        return 1
    }
    if ((Get-ConfigValue -Config $Context.Config -Key $key) -eq $value) {
        Write-Host ('  {0} 已设置为 {1}' -f $key, $value) -ForegroundColor Green
        return 0
    }
    # 布尔 / 数字项写入后字符串化可能与输入不同（如 开 → True），写盘成功即算成功
    Write-Host ('  {0} 现在的值是: {1}' -f $key, [string](Get-ConfigValue -Config $Context.Config -Key $key)) -ForegroundColor Green
    return 0
}
