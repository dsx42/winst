#Requires -Version 5.1

function Update-WinstContext {
    <#
    .SYNOPSIS
        就地应用已解析的上下文，未提供时从当前配置重新构造。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context,
        [hashtable]$NextContext
    )

    if (-not $NextContext) {
        $NextContext = New-WinstContext -Options (Get-WinstState -Name WinstOptions) -DataRoot $Context.DataRoot
    }
    foreach ($key in $NextContext.Keys) { $Context[$key] = $NextContext[$key] }
}
