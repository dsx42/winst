#Requires -Version 5.1

function Register-WinstSelfLedger {
    <#
    .SYNOPSIS
        ⑤ 系统项（首次安装补齐缺失项，更新只替换文件）⑥ 写台账（managed = winst，卸载 / 修复照常）。
    .DESCRIPTION
        落盘走 Save-WinstInstalledAppEntry（重读最新台账、只覆盖这一条），
        首次安装与更新靠 `installedAt` / `updatedAt` 区分。
        更新不重建系统项，但保留台账中的实际写入归属，供后续卸载回收。
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
    $shortcutHashes = @{}
    if ($Updated) {
        $stateRead = Read-WinstState -InstallRoot $Context.InstallRoot
        if ($stateRead.Error -and -not $stateRead.Reset) { throw $stateRead.Error }
        $previous = Get-WinstInstalledApp -State $stateRead.State -Id 'winst'
        $appliedEnv = @(Get-EntryArray -Entry $previous -Key 'appliedEnv')
        $appliedPath = @(Get-EntryArray -Entry $previous -Key 'appliedPath')
        $appliedShortcuts = @(Get-EntryArray -Entry $previous -Key 'appliedShortcuts')
        $shortcutHashes = Get-EntryValue -Entry $previous -Key 'appliedShortcutHashes' -Default @{}
    }
    if ($Plan -and -not $Updated) {
        try {
            $systemItems = Set-WinstAppSystemItems -Context $Context -Plan $Plan -InstallDir $InstallDir -KeepExisting
            $appliedEnv = @($systemItems.AppliedEnv)
            $appliedPath = @($systemItems.AppliedPath)
            $appliedShortcuts = @($systemItems.AppliedShortcuts)
            $shortcutHashes = $systemItems.ShortcutHashes
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

    # 类型按软件定义记；完整运行树（winst.ps1 + winst.cmd + Modules\）默认是 portable。
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
        appliedShortcutHashes = $shortcutHashes
        uninstall        = $uninstall
    })
    return @{ Version = $version }
}
