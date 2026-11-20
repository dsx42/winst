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
    try {
        switch ($kind.Trim().ToLowerInvariant()) {
            'direct' { $result = Resolve-DirectSource -Context $Context -Entry $Entry }
            'github' { $result = Resolve-GithubSource -Context $Context -Entry $Entry }
            'listing' { $result = Resolve-ListingSource -Context $Context -Entry $Entry }
            'page' { $result = Resolve-PageSource -Context $Context -Entry $Entry }
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
            foreach ($file in @($result.Files)) {
                $header = Get-EntryString -Entry $file -Key 'hashHeader'
                if (-not $header) { continue }
                $hash = Get-WinstRemoteHeader -Context $Context -Uri ([string]$file['url']) -Name $header
                if ($hash -notmatch '^(?:[0-9a-fA-F]{32}|[0-9a-fA-F]{40}|[0-9a-fA-F]{64}|[0-9a-fA-F]{128})$') {
                    throw ('响应头 {0} 不是有效的十六进制摘要' -f $header)
                }
                $file['hash'] = $hash
            }
        } catch { $result.Ok = $false; $result.Error = $_.Exception.Message }
    }
    if ($result.Ok) {
        $nameError = Get-WinstDuplicateDownloadNameError -Files $result.Files
        if ($nameError) { $result.Ok = $false; $result.Error = $nameError }
    }
    return $result
}
