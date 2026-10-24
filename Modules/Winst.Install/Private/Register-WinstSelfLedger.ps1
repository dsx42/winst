#Requires -Version 5.1

function Register-WinstSelfLedger {
    <#
    .SYNOPSIS
        ⑤ 系统项（首次安装补齐缺失项，更新只替换文件）⑥ 写台账（managed = winst，卸载 / 修复照常）。
    .DESCRIPTION
        落盘走 Save-WinstInstalledAppEntry（重读最新台账、只覆盖这一条），
        首次安装与更新靠 `installedAt` / `updatedAt` 区分。
        版本号：本次确实取到（或下载到）了清单里的包时用 `SourceVersion`，
        否则用当前运行副本的产品版本号。
    .OUTPUTS
        @{ Version }
    #>
    param([hashtable]$Context, $Plan, [string]$InstallDir, [bool]$Updated, [bool]$Resolved,
        [string]$SourceVersion, [string]$SourceName, [switch]$Quiet)

    $appliedEnv = @()
    $appliedPath = @()
    $appliedShortcuts = @()
    if ($Plan -and -not $Updated) {
        try {
            $systemItems = Set-WinstAppSystemItems -Context $Context -Plan $Plan -InstallDir $InstallDir -KeepExisting
            $appliedEnv = @($systemItems.AppliedEnv)
            $appliedPath = @($systemItems.AppliedPath)
            $appliedShortcuts = @($systemItems.AppliedShortcuts)
            if (-not $Quiet) {
                foreach ($note in @($systemItems.Notes)) {
                    if ($note) { Write-Host ('    提示: {0}' -f $note) -ForegroundColor DarkYellow }
                }
            }
        } catch {
            if (-not $Quiet) { Write-Host ('    提示: 落地快捷方式失败：{0}' -f $_.Exception.Message) -ForegroundColor DarkYellow }
        }
    }

    $version = (Get-WinstProductVersion)
    if ($Resolved -and $SourceVersion) { $version = $SourceVersion }
    $uninstall = ConvertTo-WinstUninstallSnapshot -Block $null
    $manifestOrigin = ''
    if ($Plan) {
        $uninstall = Get-WinstUninstallSnapshotFromPlan -Plan $Plan
        $manifestOrigin = $SourceName
    }

    # 类型按软件定义记：winst 现在是目录形态（winst.ps1 + winst.cmd + Modules\），
    # 清单里写的是 portable。旧代码固定成 'file'，那是单文件时代的布局，会让
    # `winst list` 把目录版报成单文件。
    $type = 'portable'
    if ($Plan) {
        $planType = (Get-EntryString -Entry $Plan -Key 'type').Trim().ToLowerInvariant()
        if ($planType) { $type = $planType }
    }

    $null = Save-WinstInstalledAppEntry -InstallRoot $Context.InstallRoot -Id 'winst' -Entry ([ordered]@{
        version          = $version
        type             = $type
        group            = ''
        installDir       = $InstallDir
        manifestOrigin   = $manifestOrigin
        managed          = 'winst'
        appliedEnv       = $appliedEnv
        appliedPath      = $appliedPath
        appliedShortcuts = $appliedShortcuts
        uninstall        = $uninstall
    })
    return @{ Version = $version }
}
