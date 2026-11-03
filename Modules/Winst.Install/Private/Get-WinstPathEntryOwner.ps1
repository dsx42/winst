#Requires -Version 5.1

function Get-WinstPathEntryOwner {
    <#
    .SYNOPSIS
        返回仍声明同一 PATH 项的其它已装软件 id；没有时返回空串。
    .DESCRIPTION
        有就保留该项——只有最后一个用到它的软件卸载时才会真正移除。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][hashtable]$State,
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Scope,
        [string]$ExceptId = ''
    )

    foreach ($key in @($State['Installed'].Keys)) {
        $otherId = [string]$key
        if ($ExceptId -and $otherId -ceq $ExceptId) { continue }
        $other = Get-WinstInstalledApp -State $State -Id $otherId
        if (-not $other) { continue }
        $declared = Get-WinstInstalledDeclaredItems -Context $Context -Id $otherId -Entry $other
        foreach ($item in @($declared.PathItems)) {
            if (([string]$item['path']) -ieq $Path -and ([string]$item['scope']) -eq $Scope) { return $otherId }
        }
    }
    return ''
}
