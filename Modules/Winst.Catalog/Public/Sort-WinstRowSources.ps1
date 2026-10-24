#Requires -Version 5.1

function Sort-WinstRowSources {
    <#
    .SYNOPSIS
        按默认优先级重排一行里的软件源（本地清单 → 内置源 → 其它来源按添加顺序；未登记的来源排最后）。
    .DESCRIPTION
        `-InstalledVersion` 用于更新场景：**有「比本机更新」版本的来源排在最前面**（同一层内再按默认优先级），
        避免默认优先级里排第一的来源版本反而更旧、导致更新变成「无更新可做」。
    .OUTPUTS
        重排后的行（`Sources` 第一位即默认要用的来源）
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        $Row,
        [string]$InstalledVersion = ''
    )

    if (-not $Row) { return $Row }
    $sources = @($Row['Sources'])
    if ($sources.Count -le 1) { return $Row }

    $map = Get-WinstSourcePriority -Context $Context
    $sorted = @($sources | Sort-Object -Property `
        @{ Expression = {
            if (-not $InstalledVersion) { return 0 }
            $version = [string]$_['Version']
            if ($_['Ok'] -and $version -and ((Compare-WinstVersion -A $version -B $InstalledVersion) -gt 0)) { return 0 }
            return 1
        } },
        @{ Expression = {
            $name = [string]$_['Source']
            if ($name -and $map.ContainsKey($name)) { return [int]$map[$name] }
            return 99
        } },
        @{ Expression = { [string]$_['Source'] } })

    return [ordered]@{
        Id          = $Row['Id']
        Name        = $Row['Name']
        Description = $Row['Description']
        Group       = [string]$Row['Group']
        Sources     = @($sorted)
    }
}
