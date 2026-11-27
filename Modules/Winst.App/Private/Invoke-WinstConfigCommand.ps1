#Requires -Version 5.1

function Invoke-WinstConfigCommand {
    <#
    .SYNOPSIS
        CLI：winst config get|set|reset|list [<key> [<value>]]。
    .OUTPUTS
        [int] 退出码：0 成功 / 1 参数或键名问题
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string[]]$Arguments
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
    if (@('list', 'get', 'set', 'reset') -notcontains $sub) {
        Write-WinstUnknownSubcommand -Sub $sub -Usage 'winst config get|set|reset|list [<key> [<value>]]'
        return 1
    }
    $expected = @{ list = 1; get = 2; set = 3; reset = 2 }[$sub]
    if ($tokens.Count -gt $expected -or $key.StartsWith('-')) {
        Write-Host '  config 含未知或多余参数。' -ForegroundColor Yellow
        return 1
    }

    $keys = @($Context.Config.Keys | Sort-Object)

    if ($sub -ne 'list' -and -not $key) {
        Write-Host ''
        Write-Host ('  用法: winst config {0} <key>' -f $sub) -ForegroundColor Yellow
        return 1
    }
    if ($sub -ne 'list' -and $keys -notcontains $key) {
        Write-Host ''
        Write-Host ('  没有「{0}」这个配置项。' -f $key) -ForegroundColor Yellow
        Write-Host ('  可用: {0}' -f ($keys -join '、')) -ForegroundColor DarkGray
        return 1
    }

    if ($sub -in @('list','get')) {
        if ($sub -eq 'list') { Write-Section 'winst config list' }
        else { $keys = @($key) }
        Write-Host ''
        if ('fluxdownApi' -in $keys -or 'fluxdownToken' -in $keys) { $flux = Get-WinstFluxSettings -Config $Context.Config }
        foreach ($one in $keys) {
            if ($one -eq 'fluxdownToken') { $tag = $flux.TokenTag; $display = $flux.TokenDisplay }
            elseif ($one -eq 'fluxdownApi') { $tag = $flux.AddressTag; $display = $flux.Address }
            else {
                $tag = Get-ConfigTag -Context $Context -Key $one
                $display = Get-ConfigValue -Config $Context.Config -Key $one
                if ($one -in @('installRoot','pkgDir') -and $tag -notin @('[默认]','[自定义]')) { $display = $Context[$one] }
            }
            Write-Host ('  {0} = {1}    {2}' -f $one, $display, $tag) -ForegroundColor Gray
        }
        return 0
    }

    if ($sub -eq 'reset') {
        if ($key -notin @('proxy','fluxdownApi','fluxdownToken')) {
            Write-Host '  reset 支持 proxy、fluxdownApi 和 fluxdownToken。' -ForegroundColor Yellow
            return 1
        }
        if (Set-ConfigValue -Context $Context -Key $key -DisplayName $key -Value '') { return 0 }
        return 1
    }

    if ($key -eq 'fluxdownToken') {
        if ($tokens.Count -gt 2) {
            Write-Host '  请运行 winst config set fluxdownToken，并按提示隐藏输入。' -ForegroundColor Yellow
            return 1
        }
        if (Read-WinstFluxTokenSetting -Context $Context) { return 0 }
        return 1
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
    return 0
}
