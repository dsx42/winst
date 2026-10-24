#Requires -Version 5.1

function Merge-WinstUninstallEnvItems {
    <#
    .SYNOPSIS
        ④ 合并环境变量与 PATH 项：已登记的实际值 + 两处卸载定义里声明的值，按「名称|作用域」去重。
    .OUTPUTS
        @{ Env; Path }
    #>
    param($Entry, $RecordSnapshot, $ManifestSnapshot, [string]$DefaultScope, [string]$InstallDir, [string]$InstallRoot)

    $envList = @()
    $envSeen = New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase)
    $pathList = @()
    $pathSeen = New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase)

    foreach ($item in @(Get-EntryArray -Entry $Entry -Key 'appliedEnv')) {
        $text = (Get-EntryString -Entry $item -Key 'name').Trim()
        if (-not $text) { continue }
        $scopeText = 'User'
        if ((Get-EntryString -Entry $item -Key 'scope') -eq 'Machine') { $scopeText = 'Machine' }
        $key = $text + '|' + $scopeText
        if ($envSeen.ContainsKey($key)) { continue }
        $envSeen[$key] = $true
        $envList += [ordered]@{ name = $text; scope = $scopeText }
    }
    foreach ($snapshot in @($RecordSnapshot, $ManifestSnapshot)) {
        foreach ($name in @($snapshot['removeEnv'])) {
            $text = ([string]$name).Trim()
            if (-not $text) { continue }
            $scopeText = 'User'
            if ($DefaultScope -eq 'Machine') { $scopeText = 'Machine' }
            $key = $text + '|' + $scopeText
            if ($envSeen.ContainsKey($key)) { continue }
            $envSeen[$key] = $true
            $envList += [ordered]@{ name = $text; scope = $scopeText }
        }
    }

    # PATH 项：同上（清单里写的是 {installDir}\bin 这类写法，按本机安装目录展开后再比对/回收）
    foreach ($item in @(Get-EntryArray -Entry $Entry -Key 'appliedPath')) {
        $text = (Get-EntryString -Entry $item -Key 'path').Trim()
        if (-not $text) { continue }
        $scopeText = 'User'
        if ((Get-EntryString -Entry $item -Key 'scope') -eq 'Machine') { $scopeText = 'Machine' }
        $key = $text + '|' + $scopeText
        if ($pathSeen.ContainsKey($key)) { continue }
        $pathSeen[$key] = $true
        $pathList += [ordered]@{ path = $text; scope = $scopeText }
    }
    foreach ($snapshot in @($RecordSnapshot, $ManifestSnapshot)) {
        foreach ($value in @($snapshot['removePaths'])) {
            $expanded = Expand-PlanPlaceholders -Value ([string]$value) -InstallDir $InstallDir -InstallRoot $InstallRoot
            $text = ([string]$expanded).Trim()
            if (-not $text) { continue }
            $scopeText = 'User'
            if ($DefaultScope -eq 'Machine') { $scopeText = 'Machine' }
            $key = $text + '|' + $scopeText
            if ($pathSeen.ContainsKey($key)) { continue }
            $pathSeen[$key] = $true
            $pathList += [ordered]@{ path = $text; scope = $scopeText }
        }
    }

    return @{ Env = @($envList); Path = @($pathList) }
}
