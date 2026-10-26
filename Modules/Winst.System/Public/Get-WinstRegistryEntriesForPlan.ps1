#Requires -Version 5.1

function Get-WinstRegistryEntriesForPlan {
    <#
    .SYNOPSIS
        按条目的名称规则，从系统安装记录（注册表卸载项）里选出**全部**命中的记录（按优先级排序）。
    .DESCRIPTION
        同一个软件可能同时留下多条卸载记录：升级后旧版本没被清掉时，新旧两版各有一条；
        burn 引导包与内层 MSI 也会各留一条。只取一条会让「本机版本」停留在旧版本上，
        因此这里返回全部命中，由调用方按版本挑出最新的一条。

        排序规则与原有单选规则一致：`InstallLocation` 等于预期安装目录的记录在前，
        其余按 DisplayName 字典序——保证「实际安装目录」仍然取自和以前同一条记录。
        版本高低由调用方用 Compare-WinstVersion 判断，不在这里按 DisplayVersion 排序：
        同一软件的多条记录可能用不同的版本号体系（MSI 的 80.x 与安装器的 10.x），
        按 DisplayVersion 排会选出错的记录。

        名称规则优先 `detect.name`，未声明时按条目名称推导（与修复安装记录一致）。
    .OUTPUTS
        [object[]]：命中的卸载记录；无规则 / 无命中时返回空数组
    #>
    param($Plan, [string]$InstallDir = '')

    $ruleText = Get-WinstRegistryNameRuleForPlan -Plan $Plan
    if (-not $ruleText) { return @() }
    $rule = New-MatchRule -Rule $ruleText -Kind '软件名称'
    if (-not $rule.Ok) { return @() }

    $hits = @()
    foreach ($entry in @(Get-WinstInstalledRegistryEntries)) {
        if (Test-CompiledMatchRule -Rule $rule -Text ([string]$entry['DisplayName'])) { $hits += $entry }
    }
    if ($hits.Count -eq 0) { return @() }

    $preferred = @()
    $others = @()
    if ($InstallDir) {
        $expected = ([string]$InstallDir).TrimEnd('\')
        foreach ($hit in $hits) {
            $location = ConvertTo-WinstDirPath -Text (Get-EntryString -Entry $hit -Key 'InstallLocation')
            if ($location -and $location -ieq $expected) { $preferred += $hit } else { $others += $hit }
        }
    } else {
        $others = @($hits)
    }
    $sorted = @($others | Sort-Object -Property @{ Expression = { [string]$_['DisplayName'] } })
    return @(@($preferred) + @($sorted))
}
