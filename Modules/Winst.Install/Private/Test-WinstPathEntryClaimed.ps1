#Requires -Version 5.1

function Test-WinstPathEntryClaimed {
    <#
    .SYNOPSIS
        安装记录里是否还有别的**未卸载**软件（同一作用域）声明了同一个 PATH 项。
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
            if (([string]$item['path']) -ieq $Path -and ([string]$item['scope']) -eq $Scope) { return $true }
        }
    }
    return $false
}
