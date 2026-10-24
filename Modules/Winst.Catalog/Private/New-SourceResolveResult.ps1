#Requires -Version 5.1

function New-SourceResolveResult {
    <#
    .SYNOPSIS
        构造来源解析的统一返回契约。
    #>
    param([string]$Kind = '')

    return @{
        Ok      = $false
        Kind    = $Kind
        Version = ''
        Tag     = ''
        Repo    = ''
        Files   = @()
        Notes   = @()
        Error   = ''
    }
}
