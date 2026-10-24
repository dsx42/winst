#Requires -Version 5.1

function Get-WinstVersionFromRegistry {
    <#
    .SYNOPSIS
        detect.method = registry：从系统安装记录（Uninstall 键）读版本。
    #>
    param(
        [hashtable]$Context,
        $Plan,
        $Detect,
        [string]$InstallDir = '',
        [string]$Kind = '',
        $Between = @(),
        [hashtable]$Result
    )

    # 记录选择与实际安装目录解析共用同一套规则，保证两者取自同一条记录（见 Get-WinstRegistryEntryForPlan）
    $chosen = Get-WinstRegistryEntryForPlan -Plan $Plan -InstallDir $InstallDir
    if (-not $chosen) { return }

    $Result.Found = $true
    $detail = ('系统安装记录: {0}' -f (Get-EntryString -Entry $chosen -Key 'DisplayName'))
    Set-WinstDetectedVersionFromRaw -Result $Result -Raw ([string]$chosen['DisplayVersion']) `
        -Kind $Kind -Between $Between -Detail $detail
}
