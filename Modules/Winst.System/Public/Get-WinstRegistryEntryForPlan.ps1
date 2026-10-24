#Requires -Version 5.1

function Get-WinstRegistryEntryForPlan {
    <#
    .SYNOPSIS
        按条目的名称规则，从系统安装记录（注册表卸载项）里选出唯一一条记录；选不中返回 $null。
    .DESCRIPTION
        选择规则与版本检测一致：先取 InstallLocation 等于预期安装目录（installRoot\id）的记录，
        取不到再取 DisplayName 字典序第一的那条——保证「版本」与「实际安装目录」来自同一条记录。
        名称规则优先 detect.name，未声明时按条目名称推导（与修复安装记录一致）。
    #>
    param($Plan, [string]$InstallDir = '')

    $ruleText = Get-WinstRegistryNameRuleForPlan -Plan $Plan
    if (-not $ruleText) { return $null }
    $rule = New-MatchRule -Rule $ruleText -Kind '软件名称'
    if (-not $rule.Ok) { return $null }

    $hits = @()
    foreach ($entry in @(Get-WinstInstalledRegistryEntries)) {
        if (Test-CompiledMatchRule -Rule $rule -Text ([string]$entry['DisplayName'])) { $hits += $entry }
    }
    if ($hits.Count -eq 0) { return $null }

    if ($InstallDir) {
        $expected = ([string]$InstallDir).TrimEnd('\')
        foreach ($hit in $hits) {
            $location = ConvertTo-WinstDirPath -Text (Get-EntryString -Entry $hit -Key 'InstallLocation')
            if ($location -and $location -ieq $expected) { return $hit }
        }
    }
    $sorted = @($hits | Sort-Object -Property @{ Expression = { [string]$_['DisplayName'] } })
    return $sorted[0]
}
