#Requires -Version 5.1

function Read-WinstFluxTokenSetting {
    param([hashtable]$Context)

    $secret = Read-Host '  请输入 FluxDown API Token（隐藏输入，直接回车取消）' -AsSecureString
    if ($null -eq $secret) { return $true }
    try {
        if (-not $secret.Length) { return $true }
        return Set-ConfigValue -Context $Context -Key 'fluxdownToken' -DisplayName 'FluxDown API Token' -Value $secret
    } finally { $secret.Dispose() }
}
