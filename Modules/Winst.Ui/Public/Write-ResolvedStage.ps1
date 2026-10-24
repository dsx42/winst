#Requires -Version 5.1

function Write-ResolvedStage {
    <#
    .SYNOPSIS
        输出解析锁中的一个阶段：首行带阶段标记，其余行按同一内容列对齐。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Marker,
        [Parameter(Mandatory = $true)][string]$Label,
        [string[]]$Lines = @(),
        [string]$Color = 'Gray'
    )

    $head = '    {0} {1}' -f $Marker, $Label
    $pad = 14 - (Get-DisplayWidth -Text $head)
    if ($pad -lt 1) { $pad = 1 }
    $headText = $head + (' ' * $pad)

    $items = @($Lines)
    if ($items.Count -eq 0) { $items = @('（无）') }

    Write-Host ($headText + [string]$items[0]) -ForegroundColor $Color
    $indent = ' ' * 14
    for ($i = 1; $i -lt $items.Count; $i++) {
        Write-Host ($indent + [string]$items[$i]) -ForegroundColor $Color
    }
}
