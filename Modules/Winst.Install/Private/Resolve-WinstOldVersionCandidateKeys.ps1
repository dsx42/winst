#Requires -Version 5.1

function Resolve-WinstOldVersionCandidateKeys {
    <#
    .SYNOPSIS
        按版本号反查系统安装记录，返回能卸掉这个版本的**全部**卸载键（按「最该先试」排序）。
    .DESCRIPTION
        同一个版本常有两层记录，写法还不一样：

        ```
        Microsoft Windows Desktop Runtime 10.0.13 (x64)    → "...\Package Cache\{...}\xxx.exe" /uninstall
        Microsoft Windows Desktop Runtime - 10.0.13 (x64)  → MsiExec.exe /X{9B54A545-...}
        ```

        而外层引导包的卸载程序可能已被磁盘清理删掉（`%ProgramData%\Package Cache` 被清空），
        这时只有内层 MSI 还能用。因此排序规则是：

        ① 卸载器**现在可用**的在前（缓存被清理的引导包排到后面）；
        ② 可用性相同时非 MsiExec 在前（它卸载会连带移除内层 MSI 的注册），最后按显示名。
    .OUTPUTS
        [string[]]：卸载键路径；查不到返回空数组
    #>
    param($Plan, [string]$Version)

    $matched = @(Find-WinstRecordsForVersion -Plan $Plan -Version $Version)
    if ($matched.Count -eq 0) { return @() }

    $usable = @()
    $broken = @()
    foreach ($hit in $matched) {
        if (Test-WinstUninstallerUsable -Entry $hit) { $usable += $hit } else { $broken += $hit }
    }

    $keys = @()
    foreach ($group in @(@($usable), @($broken))) {
        if (@($group).Count -eq 0) { continue }
        $nonMsi = @()
        $msi = @()
        foreach ($hit in @($group)) {
            if (Test-WinstRegistryEntryIsMsi -Entry $hit) { $msi += $hit } else { $nonMsi += $hit }
        }
        foreach ($hit in @(@($nonMsi) + @($msi))) {
            $key = [string]$hit['KeyPath']
            if ($key -and $keys -notcontains $key) { $keys += $key }
        }
    }
    return $keys
}
