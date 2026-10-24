#Requires -Version 5.1

function Resolve-WinstSelectionText {
    <#
    .SYNOPSIS
        解析形如 `1 3 5` 的编号串，并给出失败原因（不是数字 / 越界）。
    .DESCRIPTION
        菜单的各类编号输入共用一套分隔符与校验：`Read-WinstSelection`、`Read-WinstIndexSelection`
        以及列表页的选择循环统一使用本函数，避免各处重复 `-split '[\s,，、]+'` + `TryParse`，新增分隔符或改提示时容易漏改。
    .OUTPUTS
        @{ Ok; Numbers; Bad; OutOfRange }   Numbers 为 1 基原值（按输入顺序去重）
    #>
    param([string]$Text, [int]$Count)

    $numbers = @()
    foreach ($token in @(([string]$Text) -split '[\s,，、]+')) {
        $item = ([string]$token).Trim()
        if (-not $item) { continue }
        $value = 0
        if (-not [int]::TryParse($item, [ref]$value)) {
            return @{ Ok = $false; Numbers = @(); Bad = $item; OutOfRange = $false }
        }
        if ($value -lt 1 -or $value -gt $Count) {
            return @{ Ok = $false; Numbers = @(); Bad = $item; OutOfRange = $true }
        }
        if ($numbers -notcontains $value) { $numbers += $value }
    }
    if ($numbers.Count -eq 0) { return @{ Ok = $false; Numbers = @(); Bad = ''; OutOfRange = $false } }
    return @{ Ok = $true; Numbers = @($numbers); Bad = ''; OutOfRange = $false }
}
