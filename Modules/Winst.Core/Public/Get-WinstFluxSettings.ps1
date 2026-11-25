#Requires -Version 5.1

function Get-WinstFluxSettings {
    param([hashtable]$Config, [string]$Address, [switch]$Authenticate)

    $raw = @{ url = $env:FLUXDOWN_URL; token = $env:FLUXDOWN_TOKEN }
    if ($Address) { $raw.url = $Address }
    $tags = @{ url = '[环境变量]'; token = '[环境变量]' }
    foreach ($pair in @{ url = 'fluxdownApi'; token = 'fluxdownToken' }.GetEnumerator()) {
        if (-not $raw[$pair.Key] -and $Config -and $Config[$pair.Value]) {
            $raw[$pair.Key] = $Config[$pair.Value]
            $tags[$pair.Key] = '[自定义]'
        }
    }

    $result = @{ Address = ''; Token = $null; TokenDisplay = '未设置'; Error = '' }
    if ((-not $raw.url -or -not $raw.token) -and $env:APPDATA) {
        $path = Join-Path $env:APPDATA 'zerx\fluxdown\config\cli.toml'
        $lineNumber = 0
        try {
            if (Test-Path -LiteralPath $path -PathType Leaf -ErrorAction Stop) {
                foreach ($line in (Get-Content -LiteralPath $path -Encoding UTF8 -ErrorAction Stop)) {
                    $lineNumber++
                    if ($line -cnotmatch '^\s*(url|token)\s*=\s*(.*)$') { continue }
                    $key = $Matches[1]
                    $value = $Matches[2]
                    if ($raw[$key]) { continue }
                    if ($value -match '^("(?:\\.|[^"\\])*")\s*(?:#.*)?$') {
                        $raw[$key] = ConvertFrom-Json -InputObject $Matches[1] -ErrorAction Stop
                    } elseif ($value -match '^''([^'']*)''\s*(?:#.*)?$') {
                        $raw[$key] = $Matches[1]
                    } else { throw '字段格式无效' }
                    $tags[$key] = '[CLI 配置]'
                }
            }
        } catch {
            if ($lineNumber) {
                $result.Error = 'FluxDown 的 cli.toml 第 {0} 行 {1} 字段格式无效' -f $lineNumber, $key
            } else { $result.Error = '无法读取 FluxDown 的 cli.toml' }
        }
    }
    if (-not $raw.url) { $raw.url = 'http://127.0.0.1:17800'; $tags.url = '[默认]' }
    $result.Address = ConvertTo-WinstFluxAddress $raw.url
    if (-not $result.Address) {
        $result.Error = 'FluxDown API 地址必须是本机回环 HTTP(S) 根地址'
        $result.Address = '地址无效'
    }
    if ($raw.token) {
        $result.TokenDisplay = '已设置'
        if ($Authenticate) {
            try {
                if ($tags.token -eq '[自定义]') { $result.Token = ConvertTo-SecureString -String $raw.token -ErrorAction Stop }
                else { $result.Token = ConvertTo-SecureString -String $raw.token -AsPlainText -Force -ErrorAction Stop }
            } catch { $result.Error = '当前用户无法读取已保存的 FluxDown Token，请在设置中重新录入' }
        }
    } else { $tags.token = '[默认]' }
    $result.AddressTag = $tags.url
    $result.TokenTag = $tags.token
    return $result
}
