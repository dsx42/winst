#Requires -Version 5.1

function Resolve-AppSource {
    <#
    .SYNOPSIS
        按 source.kind 分派到对应解析器；统一返回契约（Ok / Version / Tag / Repo / Files / Notes / Error）。
    .DESCRIPTION
        纯「读网络 + 计算」，不改动任何系统状态；异常在内部收敛为 Error，便于上层做失败隔离。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context,
        $Entry
    )

    $source = Get-EntryValue -Entry $Entry -Key 'source' -Default $null
    $kind = Get-EntryString -Entry $source -Key 'kind'

    if (-not $kind) {
        $result = New-SourceResolveResult
        $result.Error = 'source.kind 缺失'
        return $result
    }

    $result = $null
    try {
        switch ($kind.Trim().ToLowerInvariant()) {
            'direct' { $result = Resolve-DirectSource -Context $Context -Entry $Entry }
            'github' { $result = Resolve-GithubSource -Context $Context -Entry $Entry }
            'listing' { $result = Resolve-ListingSource -Context $Context -Entry $Entry }
            'page' { $result = Resolve-PageSource -Context $Context -Entry $Entry }
            'json' { $result = Resolve-JsonSource -Context $Context -Entry $Entry }
            'magnet' { $result = Resolve-MagnetSource -Context $Context -Entry $Entry }
            default {
                $result = New-SourceResolveResult -Kind $kind
                $result.Error = ('未知的来源类型: {0}' -f $kind)
            }
        }
    } catch {
        $result = New-SourceResolveResult -Kind $kind
        $result.Error = $_.Exception.Message
    }

    if ($null -eq $result) {
        $result = New-SourceResolveResult -Kind $kind
        $result.Error = '来源解析未返回结果'
    }
    return $result
}
