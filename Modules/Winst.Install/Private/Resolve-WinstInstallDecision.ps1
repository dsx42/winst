#Requires -Version 5.1

function Resolve-WinstInstallDecision {
    <#
    .SYNOPSIS
        安装前决策矩阵：装 / 跳过 / 降级 / 窄更新 / 推迟。
    .DESCRIPTION
        版本一致 → 跳过或「仅配套文件更新」；本机更新 → 不自动降级；软件源没有版本号 → 要用户确认；
        版本号取自主包文件信息时 → 推迟到取包后再判（Defer）。命中的分支会把结论写进 $Result 并置 Return。
    .OUTPUTS
        @{ Return; Result; Defer; CompanionOnly; Detected }
    #>
    param(
        [hashtable]$Context,
        $Plan,
        [string]$Type,
        $Install,
        [string]$InstallDir,
        [string]$Id,
        [string]$DisplayName,
        [string]$Version,
        $Result,
        [switch]$Quiet,
        [switch]$Force,
        [switch]$DryRun,
        [switch]$VersionFromPackage,
        [switch]$FreshMain,
        [string]$PlanFreshState = '',
        [switch]$VersionFromCachedPackage,
        [int]$CompanionDownloadCount = 0,
        [switch]$CompanionsOnly,
        [switch]$IsDownloadType,
        $Ledger,
        [string]$SourceName = ''
    )

    $deferVersionDecision = $false
    $companionOnlyUpdate = $false
    $detected = ''

    if ($IsDownloadType) {
        return @{ Return = $false; Result = $null; Defer = $false; CompanionOnly = $false; Detected = '' }
    }

    $detect = Get-WinstDetectedVersion -Context $Context -Plan $Plan -InstallDir $InstallDir
    if ($detect.Ok) { $detected = [string]$detect.Version }
    elseif ($Ledger) { $detected = [string]$Ledger['version'] }

    if ($detected -and $detected -ine 'unknown') {
        $hasTarget = [bool]$Version
        $cmp = 0
        if ($hasTarget) { $cmp = Compare-WinstVersion -A $detected -B $Version }

        # versionFromPackage：版本号只能靠现取的包得到（软件源里没有版本号；缓存里那份不代表软件源当前这一份）。
        # 本机已装、又没有 --force 时不在这里下结论：先取包（主包不沿用缓存），取到后按包内文件信息补做一次矩阵。
        # 推迟决策只在「主包确实要重新取」时有意义（远端有新包 / 没比出结论）：取到后按包内版本补做矩阵；
        # unchanged（远端无新包）时缓存版本就是目标版本，直接按矩阵下结论，不重取也不推迟
        $deferVersionDecision = [bool]($VersionFromPackage -and -not $Force -and $FreshMain)
        if ($deferVersionDecision -and -not $Quiet) {
            if ($PlanFreshState -ieq 'changed') {
                Write-Host ('  {0} 本机已安装 {1}；远端有新包（HEAD 检测），将重新下载安装包、取包后核对版本。' -f $DisplayName, $detected) -ForegroundColor DarkYellow
            } elseif ($VersionFromCachedPackage) {
                Write-Host ('  {0} 本机已安装 {1}；无法确认远端文件是否变化，将重新取包核对版本（缓存里的包是 {2}，取自包内文件信息）。' -f $DisplayName, $detected, $Version) -ForegroundColor DarkYellow
            } else {
                Write-Host ('  {0} 本机已安装 {1}；软件源里没有版本号（版本号取自主包文件信息），先取包核对版本再决定。' -f $DisplayName, $detected) -ForegroundColor DarkYellow
            }
        }

        # 版本一致：跳过安装，由用户决定是否强制重装
        if ($hasTarget -and $cmp -eq 0 -and -not $Force -and -not $deferVersionDecision) {
            if ($Type -eq 'installer') {
                if ($Ledger) {
                    Sync-WinstInstallerDecisionPath -Context $Context -Plan $Plan -InstallDir $InstallDir -Id $Id `
                        -Result $Result -Ledger $Ledger -Quiet:$Quiet
                } else {
                    $probedDir = (Resolve-WinstActualInstallDir -Plan $Plan -AssumedDir $InstallDir).Dir
                    if ($probedDir) { $Result.InstallDir = $probedDir } else { $Result.InstallDir = '' }
                }
            }
            if (-not $Ledger) {
                Register-WinstExternalInstallRecord -Context $Context -Plan $Plan -Type $Type -InstallDir $InstallDir `
                    -Id $Id -Version $detected -SourceName $SourceName -Result $Result
            }
            $same = Resolve-WinstSameVersionAction -Install $Install -InstallDir $InstallDir -DisplayName $DisplayName `
                -Detected $detected -CompanionDownloadCount $CompanionDownloadCount -HasCompanionUpdate:$CompanionsOnly `
                -Ledger $Ledger -Result $Result -DryRun:$DryRun -Quiet:$Quiet
            if ($same.CompanionOnly) {
                return @{ Return = $false; Result = $null; Defer = $false; CompanionOnly = $true; Detected = $detected }
            }
            if ($same.Return) {
                return @{ Return = $true; Result = $same.Result; Defer = $false; CompanionOnly = $false; Detected = $detected }
            }
        }

        if (-not $deferVersionDecision -and $hasTarget -and $cmp -lt 0) {
            # 软件源里是更新的版本 → 这是「更新」：直接安装（无需 --force）
            if (-not $Quiet) {
                Write-Host ('  发现新版本：已安装 {0}  →  {1}  ↑' -f $detected, $Version) -ForegroundColor Green
            }
        } elseif (-not $deferVersionDecision -and $hasTarget -and $cmp -gt 0 -and -not $Force) {
            return (Complete-WinstInstallSkip -Result $Result -Version $detected `
                -Message ('{0} 本机已安装 {1}，比软件源里的 {2} 更新{3}' -f $DisplayName, $detected, $Version, (Get-WinstForceHint -Kind 'downgrade')))
        } elseif (-not $hasTarget -and -not $Force -and -not $deferVersionDecision) {
            return (Complete-WinstInstallSkip -Result $Result -Version $detected `
                -Message ('{0} 已安装（{1}），但软件源里没有可用版本信息{2}' -f $DisplayName, $detected, (Get-WinstForceHint -Kind 'continue')))
        }
    } elseif ($detect.Found -and -not $Force) {
        $Result.Ok = $true
        $Result.Skipped = $true
        $Result.Message = ('检测到 {0} 已经安装，但无法识别版本{1}' -f $DisplayName, (Get-WinstForceHint -Kind 'continue'))
        return @{ Return = $true; Result = $Result; Defer = $false; CompanionOnly = $false; Detected = $detected }
    }

    return @{ Return = $false; Result = $null; Defer = $deferVersionDecision; CompanionOnly = $companionOnlyUpdate; Detected = $detected }
}
