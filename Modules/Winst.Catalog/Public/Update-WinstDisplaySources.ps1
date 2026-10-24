#Requires -Version 5.1

function Update-WinstDisplaySources {
    <#
    .SYNOPSIS
        按需刷新「需要展示的软件」的版本信息（Update-WinstStaleSources -OnlyIds 的便捷封装）。
    .DESCRIPTION
        展示集合为空（没有要展示的软件）时直接跳过，不做任何刷新；非空时只对集合里
        「版本信息超过 manifestTTLHours」的软件逐条解析。
    .OUTPUTS
        @{ Refreshed; Failed; Skipped; Errors }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [AllowEmptyCollection()]
        [string[]]$Ids = @(),
        [switch]$Quiet
    )

    if (@($Ids).Count -eq 0) {
        return @{ Refreshed = 0; Failed = 0; Skipped = $false; Errors = @() }
    }
    return (Update-WinstStaleSources -Context $Context -OnlyIds @($Ids) -Quiet:$Quiet)
}
