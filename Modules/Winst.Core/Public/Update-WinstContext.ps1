#Requires -Version 5.1

function Update-WinstContext {
    <#
    .SYNOPSIS
        就地应用已解析的上下文。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context,
        [hashtable]$NextContext
    )

    foreach ($key in $NextContext.Keys) { $Context[$key] = $NextContext[$key] }
}
