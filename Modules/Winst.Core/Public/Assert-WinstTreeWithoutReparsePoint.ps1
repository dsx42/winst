#Requires -Version 5.1

function Assert-WinstTreeWithoutReparsePoint {
    <#
    .SYNOPSIS
        校验路径链及整棵目录树；逐层枚举，发现重解析点即停止，绝不跟随其目标。
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    Assert-WinstSafeWritePath -Path $Path
    $pending = New-Object 'System.Collections.Generic.Stack[string]'
    $pending.Push($Path)
    while ($pending.Count -gt 0) {
        $current = $pending.Pop()
        $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw ('目录树含有重解析点，已拒绝处理：{0}' -f $current)
        }
        if ($item.PSIsContainer) {
            foreach ($child in @(Get-ChildItem -LiteralPath $current -Force -ErrorAction Stop)) {
                $pending.Push($child.FullName)
            }
        }
    }
}
