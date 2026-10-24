#Requires -Version 5.1

function Get-WinstInstalledDeclaredItems {
    <#
    .SYNOPSIS
        取某个已装软件「声明要写入」的环境变量名与 PATH 项（安装记录 + 已刷新软件清单两处合并）。
    .DESCRIPTION
        卸载时判断某项是否还有别的软件在用。只统计**仍在安装记录里**的软件；
        安装记录里的 applied* 是实际写入的登记，软件清单里的声明用于补上老记录没有登记的情况。
    .OUTPUTS
        @{ Env = @( @{ name; scope; value } ); PathItems = @( @{ path; scope } ) }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)]$Entry
    )

    $installDir = Get-EntryString -Entry $Entry -Key 'installDir'
    $scope = Get-WinstInstallScope -InstallDir $installDir

    $envItems = @()
    $envSeen = New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase)
    $pathItems = @()
    $pathSeen = New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase)

    foreach ($item in @(Get-EntryArray -Entry $Entry -Key 'appliedEnv')) {
        $name = Get-EntryString -Entry $item -Key 'name'
        if (-not $name) { continue }
        $itemScope = Get-EntryString -Entry $item -Key 'scope'
        if ($itemScope -ne 'Machine') { $itemScope = 'User' }
        $key = $name + '|' + $itemScope
        if ($envSeen.ContainsKey($key)) { continue }
        $envSeen[$key] = $true
        $envItems += [ordered]@{ name = $name; scope = $itemScope; value = $null }
    }
    foreach ($item in @(Get-EntryArray -Entry $Entry -Key 'appliedPath')) {
        $path = Get-EntryString -Entry $item -Key 'path'
        if (-not $path) { continue }
        $itemScope = Get-EntryString -Entry $item -Key 'scope'
        if ($itemScope -ne 'Machine') { $itemScope = 'User' }
        $key = $path + '|' + $itemScope
        if ($pathSeen.ContainsKey($key)) { continue }
        $pathSeen[$key] = $true
        $pathItems += [ordered]@{ path = $path; scope = $itemScope }
    }

    $plan = Get-WinstLockedPlan -Context $Context -Id $Id
    if ($plan) {
        foreach ($pair in @(Get-EntryKeyValuePairs -Entry (Get-EntryValue -Entry $plan -Key 'env' -Default $null))) {
            $name = ([string]$pair['Key']).Trim()
            if (-not $name) { continue }
            $value = Expand-PlanPlaceholders -Value ([string]$pair['Value']) -InstallDir $installDir -InstallRoot $Context.InstallRoot
            $key = $name + '|' + $scope
            if ($envSeen.ContainsKey($key)) {
                # 同名的已登记项补上「软件源声明的值」，卸载时据此恢复
                for ($i = 0; $i -lt $envItems.Count; $i++) {
                    if (([string]$envItems[$i]['name']) -ceq $name -and ([string]$envItems[$i]['scope']) -ceq $scope) {
                        $envItems[$i]['value'] = $value
                        break
                    }
                }
                continue
            }
            $envSeen[$key] = $true
            $envItems += [ordered]@{ name = $name; scope = $scope; value = $value }
        }
        foreach ($item in @(Get-EntryArray -Entry $plan -Key 'addToPath')) {
            $text = [string]$item
            if (-not $text) { continue }
            if ($text -ieq 'true' -or $text -ieq '{installDir}') { $text = $installDir }
            else { $text = Expand-PlanPlaceholders -Value $text -InstallDir $installDir -InstallRoot $Context.InstallRoot }
            if (-not $text) { continue }
            $key = $text + '|' + $scope
            if ($pathSeen.ContainsKey($key)) { continue }
            $pathSeen[$key] = $true
            $pathItems += [ordered]@{ path = $text; scope = $scope }
        }
    }

    return @{ Env = @($envItems); PathItems = @($pathItems) }
}
