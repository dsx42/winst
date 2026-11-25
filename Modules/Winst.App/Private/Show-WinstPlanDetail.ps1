#Requires -Version 5.1

function Show-WinstPlanDetail {
    <#
    .SYNOPSIS
        展示单个软件的完整安装信息（七个阶段，路径按本机设置展开）。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Plan,
        [string]$SourceName,
        $StateRead, $Ledger, [switch]$IsUpgrade, [switch]$UseCacheVersion
    )

    $shortcutDirs = Get-WinstPlanShortcutDirectories

    $installedVersion = Get-EntryString -Entry $Ledger -Key 'version'
    $installedDir = Get-EntryString -Entry $Ledger -Key 'installDir'

    Show-ResolvedAppPlan -Plan $Plan -SourceName $SourceName `
        -InstallRoot $Context.InstallRoot -PkgDir $Context.PkgDir `
        @shortcutDirs `
        -InstalledVersion $installedVersion -InstalledDir $installedDir -IsUpgrade:$IsUpgrade -UseCacheVersion:$UseCacheVersion -Context $Context -StateRead $StateRead
}
