#Requires -Version 5.1

function Merge-WinstUninstallEnvItems {
    <#
    .SYNOPSIS
        ④ 合并环境变量与 PATH 项：只回收台账中登记的实际写入项，按「名称|作用域」去重。
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
        # 覆盖前的原值要一路带到卸载侧：安装前就存在的变量要还原，不能直接删掉用户的设置
        $envList += [ordered]@{
            name     = $text
            scope    = $scopeText
            existed  = [bool](Get-EntryBool -Entry $item -Key 'existed')
            previous = (Get-EntryString -Entry $item -Key 'previous')
        }
    }
    # 清单声明不代表实际写入：首次安装可能保留用户已有变量 / PATH，卸载不能据此认领。
    # PATH 同样只使用实际写入登记。
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
    return @{ Env = @($envList); Path = @($pathList) }
}
