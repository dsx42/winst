#Requires -Version 5.1

function Format-UpdateFilesOnlyDisplay {
    <#
    .SYNOPSIS
        把「更新方式」配置显示成普通用户能看懂的说明。
    .DESCRIPTION
        文案与菜单「已装软件 → u) 更新」括号里的说明共用一处定义（Get-WinstUpdateModeText），
        避免设置页、检查更新、自定义更新各写一套说法。
    #>
    param($Value)

    if ($Value -eq $false) { return (Get-WinstUpdateModeText -Mode 'full') }
    return (Get-WinstUpdateModeText -Mode 'keep')
}
