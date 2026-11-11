#Requires -Version 5.1

function Register-WinstEngineLedger {
    <#
    .SYNOPSIS
        ④ 登记引擎专用目录的版本与卸载快照，不接管引导期间安装的系统软件。
    .DESCRIPTION
        落盘走 Save-WinstInstalledAppEntry（重读最新台账、只覆盖这一条），
        自动更新与首次引导走同一段代码，靠 `updatedAt` 与 `installedAt` 区分：
        更新时 `installedAt` 保留首次安装时间，`updatedAt` 落到本次。
    #>
    param([hashtable]$Context, $Plan, [string]$PlanId, [string]$InstallDir, [string]$SourceName)

    $null = Save-WinstInstalledAppEntry -InstallRoot $Context.InstallRoot -Id $PlanId -Entry ([ordered]@{
        version          = (Get-EntryString -Entry $Plan -Key 'version')
        type             = 'portable'
        group            = (Get-EntryString -Entry $Plan -Key 'group')
        installDir       = $InstallDir
        manifestOrigin   = $SourceName
        managed          = 'winst'
        appliedEnv       = @()
        appliedPath      = @()
        appliedShortcuts = @()
        uninstall        = (Get-WinstUninstallSnapshotFromPlan -Plan $Plan)
    })
}
