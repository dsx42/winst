#Requires -Version 5.1

function Copy-WinstState {
    <#
    .SYNOPSIS
        复制一份台账（外层 + 每个条目），供读缓存返回给调用方。
    .DESCRIPTION
        台账读缓存缓存的是**归一化后的对象**。直接把它交给调用方，调用方对条目的就地修改
        （repair 更正版本、合并大小写重复项等）会污染缓存，导致「没保存的改动在下次读里出现」。
        因此每次读都返回一份副本：调用方拿到的对象与磁盘一致、可以随意修改，
        保存与否只由 Save-WinstState 决定。

        **复制到条目层**：外层字典与每个条目各自新建，条目内的数组（`appliedEnv` 等）
        与 `uninstall` 字典按引用共享。台账的写入一律是「整条替换」
        （Set-WinstInstalledApp 换掉整个条目字典），没有就地修改条目内数组 / 嵌套字典的写法，
        因此共享引用不会被写坏；深拷贝一个几十条的台账要几十毫秒，等于把缓存的意义抵消掉。
        新增写入逻辑时也必须遵守这一条：改条目内的数组 / 嵌套字典要整体换新对象，
        不要就地改元素。

        字段按名字逐个取（而不是遍历条目的键）：条目结构由 ConvertTo-WinstInstalledEntry
        固定下来，显式取值比「枚举 Keys 再逐个复制」快一个数量级，
        且缺字段时得到 $null 而不是漏键。
    .OUTPUTS
        [hashtable] @{ SchemaVersion; Installed }
    #>
    param([Parameter(Mandatory = $true)][hashtable]$State)

    $installed = New-WinstOrdinalDictionary
    $source = $State['Installed']
    if ($null -ne $source) {
        foreach ($key in $source.Keys) {
            $entry = $source[$key]
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
                appliedFiles     = $entry['appliedFiles']
                uninstall        = $entry['uninstall']
            }
        }
    }

    return @{ SchemaVersion = $State['SchemaVersion']; Installed = $installed }
}
