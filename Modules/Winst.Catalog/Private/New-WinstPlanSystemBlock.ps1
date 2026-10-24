#Requires -Version 5.1

function New-WinstPlanSystemBlock {
    <#
    .SYNOPSIS
        ④ 环境变量 / PATH / 快捷方式 → @{ Env; Path; Desktop; StartMenu }。
    #>
    param($Entry, [string]$Version)

    $envMap = [ordered]@{}
    $envObj = Get-EntryValue -Entry $Entry -Key 'env' -Default $null
    if ($envObj -is [System.Collections.IDictionary]) {
        foreach ($key in @($envObj.Keys)) {
            $value = $envObj[$key]
            if ($null -eq $value) { continue }
            $envMap[[string]$key] = Expand-VersionPlaceholder -Text ([string]$value) -Version $Version
        }
    } elseif ($null -ne $envObj) {
        foreach ($prop in @($envObj.PSObject.Properties)) {
            if ($null -eq $prop.Value) { continue }
            $envMap[[string]$prop.Name] = Expand-VersionPlaceholder -Text ([string]$prop.Value) -Version $Version
        }
    }

    $pathList = @()
    $rawPath = Get-EntryValue -Entry $Entry -Key 'addToPath' -Default $null
    if ($rawPath -is [bool]) {
        if ($rawPath) { $pathList += '{installDir}' }
    } elseif ($null -ne $rawPath) {
        foreach ($item in @($rawPath)) {
            if ($null -eq $item) { continue }
            $text = ([string]$item).Trim()
            if (-not $text) { continue }
            if ($text -ieq 'true') { $pathList += '{installDir}'; continue }
            # 与 stripTopDir 的布尔归一化保持同一口径：字符串 "false" 不能被当成一个真实路径项写进 PATH
            if ($text -ieq 'false' -or $text -eq '0' -or $text -ieq 'no' -or $text -ieq 'off') { continue }
            $pathList += Expand-VersionPlaceholder -Text $text -Version $Version
        }
    }

    $desktop = $false
    $startMenu = $false
    $shortcutObj = Get-EntryValue -Entry $Entry -Key 'shortcuts' -Default $null
    if ($null -ne $shortcutObj) {
        $desktop = Get-EntryBool -Entry $shortcutObj -Key 'desktop'
        $startMenu = Get-EntryBool -Entry $shortcutObj -Key 'startMenu'
    }

    return @{ Env = $envMap; Path = $pathList; Desktop = $desktop; StartMenu = $startMenu }
}
