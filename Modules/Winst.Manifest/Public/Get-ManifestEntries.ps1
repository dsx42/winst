#Requires -Version 5.1

function Get-ManifestEntries {
    <#
    .SYNOPSIS
        从清单对象中取出条目数组：catalog 包裹 / 顶层数组 / 顶层单条目三种形态归一化。
    #>
    param($Manifest)

    $result = New-Object 'System.Collections.Generic.List[object]'
    if ($null -eq $Manifest) { return @() }

    # 顶层数组形态（ConvertFrom-Json 对单元素数组会解包为标量，由末尾的单条目判断兜底）
    if ($Manifest -is [System.Array]) {
        foreach ($item in @($Manifest)) { $result.Add($item) }
        return @($result.ToArray())
    }

    # catalog 包裹形态
    $apps = Get-EntryValue -Entry $Manifest -Key 'apps' -Default $null
    if ($null -ne $apps) {
        foreach ($item in @($apps)) { $result.Add($item) }
        if ($result.Count -gt 0) { return @($result.ToArray()) }
    }

    # 顶层单条目形态：自身即含 id
    if (Get-EntryString -Entry $Manifest -Key 'id') { $result.Add($Manifest) }
    return @($result.ToArray())
}
