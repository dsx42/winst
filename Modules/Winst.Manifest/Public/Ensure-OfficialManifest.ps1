#Requires -Version 5.1

function Ensure-OfficialManifest {
    <#
    .SYNOPSIS
        以内置常量归一官方源、合并重复项并置于远程源首位。
    .OUTPUTS
        [bool] 是否改动了源列表
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    $options = Get-WinstState -Name WinstOptions
    if ($options -and ($options.DryRun -or $options.Offline)) { return $false }
    $sources = @(Read-ManifestSources -PkgDir $Context.PkgDir -PreserveOfficialEntries)
    $changed = $false

    $officialName = Get-WinstOfficialManifestName
    $officialUrl = Get-WinstOfficialManifestUrl
    $rest = @()
    $officialCount = 0
    for ($i = 0; $i -lt $sources.Count; $i++) {
        $one = $sources[$i]
        if ([string]$one['name'] -ieq $officialName -or [string]$one['repo'] -ieq $officialName) {
            $officialCount++
            if ($i -ne 0 -or [string]$one['name'] -cne $officialName -or [string]$one['repo'] -cne $officialName -or [string]$one['url'] -cne $officialUrl) { $changed = $true }
        } else {
            $rest += $one
        }
    }
    if ($officialCount -ne 1) { $changed = $true }
    $sources = @([ordered]@{ name = $officialName; repo = $officialName; url = $officialUrl }) + $rest

    if ($changed) {
        try {
            Write-ManifestSources -PkgDir $Context.PkgDir -Sources $sources
        } catch {
            Write-Host ('  警告: 内置软件源写回失败: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
            return $false
        }
    }
    return $changed
}
