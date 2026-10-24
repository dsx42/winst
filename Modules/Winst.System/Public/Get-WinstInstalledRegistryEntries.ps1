#Requires -Version 5.1

function Get-WinstInstalledRegistryEntries {
    <#
    .SYNOPSIS
        枚举系统卸载记录（HKLM 含 WOW6432Node / HKCU 的 Uninstall 键）。
    .OUTPUTS
        @( @{ DisplayName; DisplayVersion; InstallLocation; UninstallString; DisplayIcon; KeyPath } )
    #>
    param([switch]$Force, [int]$TtlSeconds = 15)

    # 短 TTL 快照：一次安装 / 卸载流程会反复问「系统里有哪些卸载记录」（每个检测项、每个依赖各一次），
    # 而三个根全表枚举 + 逐键 Get-ItemProperty 单次就要几百毫秒。
    # -Force 用于「必须重读」的场景（卸载器逐条回读）；写操作后由 Reset-WinstSystemCache 立即失效。
    if (-not $Force -and (Get-WinstState -Name WinstRegistryEntriesCache)) {
        $age = ((Get-Date) - [datetime](Get-WinstState -Name WinstRegistryEntriesCache)['At']).TotalSeconds
        if ($age -ge 0 -and $age -lt $TtlSeconds) { return @((Get-WinstState -Name WinstRegistryEntriesCache)['List']) }
    }

    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    $list = New-Object 'System.Collections.Generic.List[object]'
    # 卸载键里这些属性都是可选的（实测 HKLM 下就有只写了 UninstallString 的项）：
    # StrictMode 2 下直接 $props.DisplayName 会抛 PropertyNotFoundException，
    # 于是「检查更新 / 安装 / 卸载」走到版本检测就整个中断。统一按「有没有这个属性」读。
    foreach ($root in $roots) {
        foreach ($key in @(Get-ChildItem -Path $root -ErrorAction SilentlyContinue)) {
            $props = $null
            try { $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue } catch { $props = $null }
            if ($null -eq $props) { continue }
            $row = [ordered]@{}
            foreach ($fieldName in @('DisplayName', 'DisplayVersion', 'InstallLocation', 'UninstallString', 'DisplayIcon')) {
                $fieldValue = ''
                $prop = $props.PSObject.Properties[$fieldName]
                if ($prop -and $null -ne $prop.Value) { $fieldValue = [string]$prop.Value }
                $row[$fieldName] = $fieldValue
            }
            $row['KeyPath'] = [string]$key.PSPath
            $list.Add($row)
        }
    }
    $snapshot = @($list.ToArray())
    $null = Set-WinstState -Name WinstRegistryEntriesCache -Value (@{ At = (Get-Date); List = $snapshot })
    return $snapshot
}
