#Requires -Version 5.1

function Expand-WinstListingIndexUrl {
    <#
    .SYNOPSIS
        将列表地址末段的星号通配展开为父页面上的直接子目录。
    #>
    param([hashtable]$Context, [string]$IndexUrl)

    if ($IndexUrl.IndexOf('*') -lt 0) { return $IndexUrl }
    $rawPath = $IndexUrl.TrimEnd('/')
    if ($rawPath.Substring(0, $rawPath.LastIndexOf('/') + 1).Contains('*')) {
        throw ('列表地址的星号只能写在最后一个目录名中：' + $IndexUrl)
    }
    $uri = $null
    if (-not [Uri]::TryCreate($IndexUrl, [UriKind]::Absolute, [ref]$uri) -or
            @('http', 'https') -notcontains $uri.Scheme -or $uri.Query -or $uri.Fragment) {
        throw ('通配列表地址必须是无查询串和片段的绝对 HTTP(S) 地址：' + $IndexUrl)
    }
    $path = $uri.AbsolutePath.TrimEnd('/')
    $slash = $path.LastIndexOf('/')
    $parentPath = $path.Substring(0, $slash + 1)
    $pattern = [Uri]::UnescapeDataString($path.Substring($slash + 1))
    $authority = $uri.GetLeftPart([UriPartial]::Authority)
    if ($authority.Contains('*') -or $parentPath.Contains('*') -or -not $pattern.Contains('*') -or
            $pattern.Contains('/') -or $pattern -match '^(?i)(re|preset|product):') {
        throw ('列表地址的星号只能写在最后一个目录名中：' + $IndexUrl)
    }
    $rule = New-MatchRule -Rule $pattern -Kind '列表目录名'
    if (-not $rule.Ok) { throw $rule.Error }
    $parentUrl = $authority + $parentPath
    try {
        $html = Invoke-WinstHttpGet -Uri $parentUrl -Context $Context
    } catch {
        throw ('无法打开通配列表的父目录 {0}：{1}' -f $parentUrl, $_.Exception.Message)
    }

    $directories = @()
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
    foreach ($anchor in @(Get-HtmlAnchorList -Html $html)) {
        $child = $null
        if (-not [Uri]::TryCreate([Uri]$parentUrl, [string]$anchor.Href, [ref]$child)) { continue }
        if ($child.GetLeftPart([UriPartial]::Authority) -cne $authority -or $child.Query -or $child.Fragment -or
                -not $child.AbsolutePath.EndsWith('/')) { continue }
        if (([Uri]::new($child, '..')).AbsoluteUri -cne $parentUrl) { continue }
        $name = [Uri]::UnescapeDataString($child.Segments[$child.Segments.Count - 1].TrimEnd('/'))
        if ($name.Contains('/') -or -not (Test-CompiledMatchRule -Rule $rule -Text $name)) { continue }
        if ($seen.Add($child.AbsoluteUri)) { $directories += $child.AbsoluteUri }
    }
    if ($directories.Count -eq 0) {
        throw ('通配列表地址没有匹配到直接子目录：' + $IndexUrl)
    }
    return @($directories)
}
