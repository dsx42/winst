#Requires -Version 5.1

function Write-WinstListFileRows {
    <#
    .SYNOPSIS
        统一输出清单文件的编号、名称、项数与修改时间。
    #>
    param($Files, [string]$Indent = '    ', [string]$Color = 'White')

    $items = @($Files)
    for ($i = 0; $i -lt $items.Count; $i++) {
        $file = $items[$i]
        $when = ''
        if ($file['Modified']) {
            try { $when = ([datetime]$file['Modified']).ToString('yyyy-MM-dd HH:mm') } catch { $when = '' }
        }
        Write-Host ('{0}{1}) {2}    {3} 项    {4}' -f $Indent, ($i + 1), [string]$file['Name'], [int]$file['Count'], $when) -ForegroundColor $Color
    }
}
