#Requires -Version 5.1

function Resolve-WinstEnginePlan {
    <#
    .SYNOPSIS
        取引擎条目的软件定义；取不到时强制刷新官方源再取一次。
    .OUTPUTS
        @{ Ok; Error; Plan; Source }
    #>
    param([hashtable]$Context, [string]$Id)

    $resolved = Get-WinstManifestAppPlan -Context $Context -Id $Id -PreferSource (Get-WinstOfficialManifestName)
    if (-not $resolved.Ok) {
        foreach ($source in @(Get-ManifestSourceList -Context $Context)) {
            if ([string]$source['name'] -ine (Get-WinstOfficialManifestName)) { continue }
            $null = Update-ManifestSource -Context $Context -Source $source -Force
        }
        $resolved = Get-WinstManifestAppPlan -Context $Context -Id $Id -PreferSource (Get-WinstOfficialManifestName)
    }
    if (-not $resolved.Ok) {
        return @{ Ok = $false; Error = ('无法获取 {0} 的软件定义：{1}' -f $Id, $resolved.Error); Plan = $null; Source = '' }
    }
    return @{ Ok = $true; Error = ''; Plan = $resolved.Plan; Source = [string]$resolved.Source }
}
