#Requires -Version 5.1

function Ensure-OfficialManifest {
    <#
    .SYNOPSIS
        内置源自愈：缺失则插入首位；地址与内置常量不一致则覆盖并警告回写（本次不挪位）；两者都不成立且不在首位时挪回首位。
    .OUTPUTS
        [bool] 是否改动了源列表
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    $sources = @(Get-RemoteManifestList -PkgDir $Context.PkgDir)
    $changed = $false

    $index = -1
    for ($i = 0; $i -lt $sources.Count; $i++) {
        if ([string]$sources[$i]['name'] -ieq (Get-WinstOfficialManifestName)) { $index = $i; break }
    }

    if ($index -lt 0) {
        $sources = @([ordered]@{ name = (Get-WinstOfficialManifestName); repo = (Get-WinstOfficialManifestName); url = (Get-WinstOfficialManifestUrl) }) + $sources
        $changed = $true
    } elseif ([string]$sources[$index]['url'] -ne (Get-WinstOfficialManifestUrl)) {
        $sources[$index]['url'] = (Get-WinstOfficialManifestUrl)
        $changed = $true
        Write-Host '  警告: 内置软件源地址被修改，已恢复为内置地址。' -ForegroundColor Yellow
    } elseif ($index -gt 0) {
        # 内置源固定排在首位，便于展示与查找
        $officialEntry = $sources[$index]
        $rest = @()
        for ($i = 0; $i -lt $sources.Count; $i++) {
            if ($i -ne $index) { $rest += $sources[$i] }
        }
        $sources = @($officialEntry) + $rest
        $changed = $true
    }

    if ($changed) {
        try {
            Write-ManifestSources -PkgDir $Context.PkgDir -Sources $sources
        } catch {
            Write-Host ('  警告: 内置软件源写回失败: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
        }
    }
    return $changed
}
