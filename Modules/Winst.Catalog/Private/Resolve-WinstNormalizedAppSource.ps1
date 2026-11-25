#Requires -Version 5.1

function Resolve-WinstNormalizedAppSource {
    <#
    .SYNOPSIS
        按 source.kind 解析已归一化的清单条目。
    #>
    param([hashtable]$Context, $Entry)

    $source = Get-EntryValue -Entry $Entry -Key 'source' -Default $null
    $kind = Get-EntryString -Entry $source -Key 'kind'

    $result = $null
    $cleanupErrors = @()
    try {
        switch ($kind.Trim().ToLowerInvariant()) {
            'direct' { $result = Resolve-DirectSource -Context $Context -Entry $Entry }
            'github' { $result = Resolve-GithubSource -Context $Context -Entry $Entry }
            'listing' { $result = Resolve-ListingSource -Context $Context -Entry $Entry }
            'page' {
                $sessions = New-Object Collections.ArrayList
                try { $result = Resolve-PageSource -Context $Context -Entry $Entry -Sessions $sessions }
                finally {
                    foreach ($session in $sessions) {
                        try {
                            Close-WinstDevToolsSession -Session $session
                            if ($session.CleanupError) { $cleanupErrors += $session.CleanupError }
                        } catch { $cleanupErrors += ('浏览器清理失败：{0}' -f $_.Exception.Message) }
                    }
                }
                if ($result.Ok) {
                    $url = $result.Files[0].url
                    $headers = Get-WinstBrowserHeaders
                    if ($result['Headers']) { $headers = $result.Headers[0] }
                    $probe = Test-WinstManifestUrlOrNote -Context $Context -Url $url -Skip (Get-EntryBool $source 'skipExistsCheck') -Headers $headers `
                        -MissingError ('下载页给出的地址不存在（HTTP 404）：{0}' -f $url)
                    if (-not $probe.Ok) { $result.Ok = $false; $result.Error = $probe.Error }
                    if ($probe.Note) { $result.Notes += $probe.Note }
                }
            }
            'json' { $result = Resolve-JsonSource -Context $Context -Entry $Entry }
            'xml' { $result = Resolve-XmlSource -Context $Context -Entry $Entry }
            'magnet' { $result = Resolve-MagnetSource -Entry $Entry }
        }
    } catch {
        $result = New-SourceResolveResult -Kind $kind
        $result.Error = $_.Exception.Message
    }

    if ($null -eq $result) {
        $result = New-SourceResolveResult -Kind $kind
        $result.Error = '来源解析未返回结果'
    }
    if ($result.Ok) {
        try {
            for ($i = 0; $i -lt $result.Files.Count; $i++) {
                $file = $result.Files[$i]
                $headers = $null
                if ($result['Headers']) { $headers = $result.Headers[$i] }
                $header = Get-EntryString -Entry $file -Key 'hashHeader'
                if ($header) {
                    $hash = Get-WinstRemoteHeader -Headers $headers -Context $Context -Uri ([string]$file['url']) -Name $header
                    if ($hash -notmatch '^(?:[0-9a-fA-F]{32}|[0-9a-fA-F]{40}|[0-9a-fA-F]{64}|[0-9a-fA-F]{128})$') {
                        throw ('响应头 {0} 不是有效的十六进制摘要' -f $header)
                    }
                    $file['hash'] = $hash
                }
                $size = Get-WinstCachedHeadSize -Context $Context -Uri $file['url'] -Headers $headers
                if ($null -ne $size) { $file['size'] = $size }
            }
        } catch { $result.Ok = $false; $result.Error = $_.Exception.Message }
    }
    if ($result.Ok) {
        $nameError = Get-WinstDuplicateDownloadNameError -Files $result.Files
        if ($nameError) { $result.Ok = $false; $result.Error = $nameError }
    }
    if ($cleanupErrors) {
        if ($result.Ok) { $result.Notes += $cleanupErrors }
        else { $result.Error = (@($result.Error) + $cleanupErrors) -join '；' }
    }
    return $result
}
