#Requires -Version 5.1

function Get-WinstEnvRestoreValue {
    <#
    .SYNOPSIS
        移除环境变量前，找出安装记录里最近安装、且在同一作用域声明同名变量的**未卸载**软件，算出它需要的值。
    .DESCRIPTION
        移除某项前检查其余条目在同一作用域是否声明同名项——有则恢复为其中最近安装条目的值
        （值相同的软件不会互相影响；只有最后一个使用者卸载时才会真正删除变量）。
        算不出该软件需要的值时返回 Error，调用方应保留变量、不误删。
    .OUTPUTS
        @{ Found; Value; FromId; Error }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][hashtable]$State,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Scope,
        [string]$ExceptId = ''
    )

    $result = @{ Found = $false; Value = ''; FromId = ''; Error = '' }

    $bestStamp = [datetime]::MinValue
    $bestId = ''
    $bestValue = ''
    $bestHasValue = $false

    foreach ($key in @($State['Installed'].Keys)) {
        $otherId = [string]$key
        if ($ExceptId -and $otherId -ceq $ExceptId) { continue }
        $other = Get-WinstInstalledApp -State $State -Id $otherId
        if (-not $other) { continue }

        $declared = Get-WinstInstalledDeclaredItems -Context $Context -Id $otherId -Entry $other
        $match = $null
        foreach ($item in @($declared.Env)) {
            if (([string]$item['name']) -ieq $Name -and ([string]$item['scope']) -eq $Scope) { $match = $item; break }
        }
        if (-not $match) { continue }

        $stamp = [datetime]::MinValue
        $installedAt = Get-EntryString -Entry $other -Key 'installedAt'
        if ($installedAt) { [void][datetime]::TryParse($installedAt, [ref]$stamp) }
        if ($bestId -and $stamp -le $bestStamp) { continue }

        $bestStamp = $stamp
        $bestId = $otherId
        $bestValue = ''
        $bestHasValue = $false
        if ($null -ne $match['value']) {
            $bestValue = [string]$match['value']
            $bestHasValue = $true
        }
    }

    if (-not $bestId) { return $result }
    $result.Found = $true
    $result.FromId = $bestId

    if (-not $bestHasValue) {
        $result.Error = ('软件源里没有「{0}」，无法确认它需要的值' -f $bestId)
        return $result
    }
    $result.Value = $bestValue
    return $result
}
