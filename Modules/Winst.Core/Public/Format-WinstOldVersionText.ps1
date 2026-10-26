#Requires -Version 5.1

function Format-WinstOldVersionText {
    <#
    .SYNOPSIS
        把「旧版本登记」拼成一行文本（如 `10.0.13、10.0.12`）。
    .DESCRIPTION
        检测结果里的条目用小写键（`version`），展示视图里的条目用大写键（`Version`）：
        两种形态都要认，否则同一个函数在一处能出文本、在另一处返回空串。
    .OUTPUTS
        [string] 没有旧版本时返回空串
    #>
    param($OldVersions = @())

    $parts = @()
    foreach ($item in @($OldVersions)) {
        $version = Get-EntryString -Entry $item -Key 'version'
        if (-not $version) { $version = Get-EntryString -Entry $item -Key 'Version' }
        if (-not $version) { continue }
        if ($parts -notcontains $version) { $parts += $version }
    }
    return ($parts -join '、')
}
