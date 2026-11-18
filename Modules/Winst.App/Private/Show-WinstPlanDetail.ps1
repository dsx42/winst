#Requires -Version 5.1

function Show-WinstPlanDetail {
    <#
    .SYNOPSIS
        展示单个软件的完整安装信息（七个阶段，路径按本机设置展开）。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Plan,
        [string]$SourceName = '',
        [int]$Index = 0,
        [int]$Total = 0, $StateRead, $Ledger
    )

    $shortcutDirs = Get-WinstPlanShortcutDirectories

    $installedVersion = Get-EntryString -Entry $Ledger -Key 'version'
    $installedDir = Get-EntryString -Entry $Ledger -Key 'installDir'

    Show-ResolvedAppPlan -Plan $Plan -Index $Index -Total $Total -SourceName $SourceName `
        -InstallRoot $Context.InstallRoot -PkgDir $Context.PkgDir `
        @shortcutDirs `
        -InstalledVersion $installedVersion -InstalledDir $installedDir -Context $Context -State $StateRead.State -StateRead $StateRead
}
