#Requires -Version 5.1

function Get-WinstFluxService {
    param([hashtable]$Config, [string]$Address, [switch]$Reconnect)

    $settings = Get-WinstFluxSettings -Config $Config -Address $Address -Authenticate
    if ($settings.Error) { throw $settings.Error }
    if (-not $settings.Token) { throw '未配置 Token' }
    $service = @{ Address = $settings.Address; Token = $settings.Token }
    $info = Invoke-WinstFluxApi $service GET 'info' -Reconnect:$Reconnect
    if ((Get-EntryString $info 'name') -ne 'FluxDown') { throw '管理服务身份不符' }
    return $service
}
