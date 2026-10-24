#Requires -Version 5.1

function Write-WinstGroupHeading {
    <#
    .SYNOPSIS
        列表里切换到新分组时输出一行分组标题（形如「— 7-Zip —」）；同一分组只打印一次。
    .DESCRIPTION
        与调用方的「上一分组」游标配合：传入本次条目的分组与上一次的返回值，分组变化时才打印。
        未声明 group 的条目排在列表最后（见 Sort-Winst*ByGroup）——列表里存在分组条目时，给它们打印一行
        「— 未分组 —」标题（**与普通分组标题同色**，不弱化：用户口径，淡色容易被忽略；调用方传
        `-ShowUngrouped`；不打印的话这些条目看上去仍属于上一个分组），整个列表都没有分组条目时**不打**
        （免得平白多一行）。分页时跨页的同组条目会在新页重新打印一次标题。
    .OUTPUTS
        [string] 本次处理后应记住的「上一分组」（调用方回写，供下一条比较）
    #>
    param([string]$Group, [string]$LastGroup = '', [switch]$ShowUngrouped)

    if (-not $Group) {
        if (-not $ShowUngrouped) { return '' }
        $Group = '未分组'
    }
    if ($Group -ceq $LastGroup) { return $LastGroup }
    Write-Host ('  — {0} —' -f $Group) -ForegroundColor Cyan
    return $Group
}
