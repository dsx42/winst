#Requires -Version 5.1

function Register-WinstExternalInstallRecord {
    <#
    .SYNOPSIS
        检测到同版本但台账缺失时登记为 external，不接管用户自行安装的软件。
    .DESCRIPTION
        落盘走 Save-WinstInstalledAppEntry（重读最新台账、只覆盖这一条）：
        本函数在安装流程中途调用，此时可能有引擎自动安装写入过记录。
        本机并存的低版本（`OldVersions`）一并记下，供界面提醒清理。
    #>
    param(
        [hashtable]$Context,
        $Plan,
        [string]$Type,
        [string]$InstallDir,
        [string]$Id,
        [string]$Version,
        [string]$SourceName,
        $OldVersions = @(), [switch]$LocationKnown
    )

    if ($Type -eq 'installer' -and -not $LocationKnown) {
        $InstallDir = (Resolve-WinstActualInstallDir -Plan $Plan -AssumedDir $InstallDir).Dir
    }
    $null = Save-WinstInstalledAppEntry -InstallRoot $Context.InstallRoot -Id $Id -Entry ([ordered]@{
        version          = $Version
        type             = $Type
        installDir       = $InstallDir
        manifestOrigin   = $SourceName
        managed          = 'external'
        appliedEnv       = @()
        appliedPath      = @()
        appliedShortcuts = @()
        oldVersions      = @(ConvertTo-WinstLedgerOldVersions -OldVersions $OldVersions)
    })
}
