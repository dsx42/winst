#Requires -Version 5.1

function Write-MenuItem {
    <#
    .SYNOPSIS
        输出一行菜单项，编号与说明对齐（按全角宽度对齐）。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter(Mandatory = $true)]
        [string]$Label,
        [string]$Description = ''
    )

    $head = '  {0}) {1}' -f $Key, $Label
    Write-Host $head -NoNewline -ForegroundColor White

    if ($Description) {
        $pad = 22 - (Get-DisplayWidth -Text $Label)
        if ($pad -lt 1) { $pad = 1 }
        Write-Host ((' ' * $pad) + $Description) -ForegroundColor DarkGray
    } else {
        Write-Host ''
    }
}
