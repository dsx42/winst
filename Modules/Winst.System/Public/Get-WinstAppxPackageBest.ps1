#Requires -Version 5.1

function Get-WinstAppxPackageBest {
    <#
    .SYNOPSIS
        按名称规则（通配）找出已安装的应用包（MSIX / AppX），返回最合适的一个；没有则返回 $null。
    .DESCRIPTION
        用于 detect.method = appx：Windows App Runtime、Windows Terminal 这类由
        应用包（msixbundle）安装的软件不在注册表卸载项里，只能从系统的应用包记录里读版本与安装位置。
        挑选顺序：先排除系统自带位置（%WINDIR%\SystemApps 下的收件箱包）→ 版本最高 → 同版本优先 x64 / 中性架构。
    #>
    param([string]$NameRule)

    $candidates = @(Get-WinstAppxPackagesMatching -NameRules $NameRule)
    if ($candidates.Count -eq 0) { return $null }

    $best = $null
    foreach ($package in $candidates) {
        if ($null -eq $best) { $best = $package; continue }
        $cmp = 0
        try { $cmp = Compare-WinstVersion -A ([string]$package.Version) -B ([string]$best.Version) } catch { $cmp = 0 }
        if ($cmp -gt 0) { $best = $package; continue }
        if ($cmp -lt 0) { continue }
        if ((Get-WinstAppxArchRank -Architecture ([string]$package.Architecture)) -gt (Get-WinstAppxArchRank -Architecture ([string]$best.Architecture))) {
            $best = $package
        }
    }
    return $best
}
