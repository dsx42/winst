#Requires -Version 5.1

function Get-WinstRowSourceText {
    <#
    .SYNOPSIS
        把一行的各来源与版本格式化为一行文本（如 `dsx42/winst-manifest (1.2.3)、local (1.2.2)`）。
    #>
    param($Row)

    $parts = @()
    foreach ($entry in @($Row['Sources'])) {
        $version = [string]$entry['Version']
        if (-not $version) { $version = '未知' }
        $mark = ''
        if (-not $entry['Ok']) { $mark = '·不可用' }
        $parts += ('{0} ({1}){2}' -f [string]$entry['Source'], $version, $mark)
    }
    return ($parts -join '、')
}
