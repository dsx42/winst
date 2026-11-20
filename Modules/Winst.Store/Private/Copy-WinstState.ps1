#Requires -Version 5.1

function Copy-WinstState {
    <#
    .SYNOPSIS
        复制台账的外层字典及选定条目，供读缓存返回给调用方。
    .DESCRIPTION
        默认复制到条目层。条目内的数组与嵌套字典按引用共享；
        指定 ShareEntries 时整个条目按引用共享。修改台账须用 Set-WinstInstalledApp
        整条替换，并为要修改的数组或嵌套字典构造新值。

        字段按名字逐个取（而不是遍历条目的键）：条目结构由 ConvertTo-WinstInstalledEntry
        固定下来，显式取值比「枚举 Keys 再逐个复制」快一个数量级，
        且缺字段时得到 $null 而不是漏键。
    .OUTPUTS
        [hashtable] @{ SchemaVersion; Installed }
    #>
    param([Parameter(Mandatory = $true)][hashtable]$State, [switch]$ShareEntries, [string[]]$Ids)

    $installed = New-WinstOrdinalDictionary
    $source = $State['Installed']
    if ($null -ne $source) {
        $keys = $source.Keys
        if ($PSBoundParameters.ContainsKey('Ids')) { $keys = $Ids }
        foreach ($key in $keys) {
            if (-not $source.Contains($key)) { continue }
            $entry = $source[$key]
            if ($ShareEntries) { $installed[$key] = $entry; continue }
            if ($null -eq $entry) { $installed[$key] = $null; continue }
            $installed[$key] = [ordered]@{
                version          = $entry['version']
                type             = $entry['type']
                group            = $entry['group']
                installDir       = $entry['installDir']
                installedAt      = $entry['installedAt']
                updatedAt        = $entry['updatedAt']
                manifestOrigin   = $entry['manifestOrigin']
                managed          = $entry['managed']
                appliedEnv       = $entry['appliedEnv']
                appliedPath      = $entry['appliedPath']
                appliedShortcuts = $entry['appliedShortcuts']
                appliedShortcutHashes = $entry['appliedShortcutHashes']
                appliedFileVersions = $entry['appliedFileVersions']
                appliedFiles     = $entry['appliedFiles']
                appliedFileRules = $entry['appliedFileRules']
                oldVersions      = $entry['oldVersions']
                uninstall        = $entry['uninstall']
            }
        }
    }

    return @{ SchemaVersion = $State['SchemaVersion']; Installed = $installed }
}
