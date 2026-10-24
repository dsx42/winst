#Requires -Version 5.1

function Get-WinstSourcePriority {
    <#
    .SYNOPSIS
        软件源的默认优先级表：本地清单 local → 内置源 → 其它来源按添加顺序。
    .OUTPUTS
        @{ <源名> = <序号> }（序号越小越优先）
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    $map = New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase)
    $map[(Get-WinstLocalManifestName)] = 0
    $map[(Get-WinstOfficialManifestName)] = 1
    $index = 2
    foreach ($source in @(Get-ManifestSourceList -Context $Context)) {
        $name = [string]$source['name']
        if (-not $name) { continue }
        if ($map.ContainsKey($name)) { continue }
        $map[$name] = $index
        $index++
    }
    return $map
}
