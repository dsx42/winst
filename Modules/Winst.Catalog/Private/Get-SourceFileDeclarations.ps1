#Requires -Version 5.1

function Get-SourceFileDeclarations {
    <#
    .SYNOPSIS
        读取归一化的 source.files，或把单独声明的 source.url 包装为主包。
    #>
    param($Source)

    if ($Source.Contains('files')) { return $Source['files'] }
    if ($Source.Contains('url')) {
        $url = $Source['url'].Trim()
        if (-not $url) { throw 'source.url 必须是非空地址字符串' }
        return [ordered]@{ url = $url }
    }
    return @()
}
