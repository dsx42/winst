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
        [int]$Total = 0
    )

    $desktopDir = ''
    try { $desktopDir = [Environment]::GetFolderPath('Desktop') } catch { $desktopDir = '' }
    $startMenuDir = ''
    if ($env:APPDATA) { $startMenuDir = Join-WinstPath $env:APPDATA 'Microsoft\Windows\Start Menu\Programs' }

    # 本机已装版本与安装路径：用于在详情里突出「将更新到 x.y ↑」，并说明当前装在哪
    $installedVersion = ''
    $installedDir = ''
    $id = Get-EntryString -Entry $Plan -Key 'id'
    if ($id) {
        $state = (Read-WinstState -InstallRoot $Context.InstallRoot).State
        $ledger = Get-WinstInstalledApp -State $state -Id $id
        if ($ledger) {
            $installedVersion = Get-EntryString -Entry $ledger -Key 'version'
            $installedDir = Get-EntryString -Entry $ledger -Key 'installDir'
        }
    }

    Show-ResolvedAppPlan -Plan $Plan -Index $Index -Total $Total -SourceName $SourceName `
        -InstallRoot $Context.InstallRoot -PkgDir $Context.PkgDir `
        -DesktopDir $desktopDir -StartMenuDir $startMenuDir `
        -InstalledVersion $installedVersion -InstalledDir $installedDir -Context $Context
}
