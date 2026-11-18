#Requires -Version 5.1

function Format-WinstOldVersionText {
    <#
    .SYNOPSIS
        把「旧版本登记」拼成一行文本（如 `10.0.13、10.0.12`）。
    .DESCRIPTION
        台账字段为 version，检测结果和展示视图字段为 Version。
        传入区分大小写的字典时，优先读取非空的 version。
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
