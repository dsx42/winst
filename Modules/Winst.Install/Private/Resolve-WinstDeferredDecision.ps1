#Requires -Version 5.1

function Resolve-WinstDeferredDecision {
    <#
    .SYNOPSIS
        versionFromPackage 的推迟决策：主包到手后按包内版本补做一次「更新 / 跳过 / 不降级」判断。
    .DESCRIPTION
        本机已装、版本号拿不到（或只有缓存里那份的读数）时不直接跳过：主包已经取到，这里用包内文件信息
        得到的版本补做一次决策矩阵——软件源里更新 → 直接安装（更新）；版本相同 → 跳过（交互式由调用方再问
        是否强制重装）；仍是本机更新 → 不自动降级；连包内也没有版本信息 → 仍按「要用户确认才继续」处理
        （命令行侧提示加 --force，菜单侧紧跟着问是否强制重装，见 Get-WinstForceHint）。
    .OUTPUTS
        @{ Return; Result; CompanionOnly }
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
        [string]$Detected,
        $Result,
        $Ledger,
        [int]$CompanionDownloadCount = 0,
        [switch]$Defer,
        [switch]$Quiet,
        # 调用方显式传了 -SourceName；不声明的话只能靠动态作用域读到调用方变量（换调用点或 StrictMode 就断）
        [string]$SourceName = ''
    )

    if (-not $Defer) { return @{ Return = $false; Result = $null; CompanionOnly = $false } }

    if (-not $Version) {
        return (Complete-WinstInstallSkip -Result $Result -Version $Detected `
            -Message ('{0} 已安装（{1}），但软件源里没有可用版本信息{2}' -f $DisplayName, $Detected, (Get-WinstForceHint -Kind 'continue')))
    }

    $companionOnlyUpdate = $false
    $cmpAfterPackage = Compare-WinstVersion -A $Detected -B $Version
    if ($cmpAfterPackage -eq 0) {
        if (-not $Ledger) {
            Register-WinstExternalInstallRecord -Context $Context -Plan $Plan -Type $Type -InstallDir $InstallDir `
                -Id $Id -Version $Detected -SourceName $SourceName -Result $Result
        }
        $same = Resolve-WinstSameVersionAction -Install $Install -InstallDir $InstallDir -DisplayName $DisplayName `
            -Detected $Detected -CompanionDownloadCount $CompanionDownloadCount `
            -HasCompanionUpdate:($CompanionDownloadCount -gt 0) -Ledger $Ledger -Result $Result -Quiet:$Quiet
        if ($same.CompanionOnly) {
            return @{ Return = $false; Result = $null; CompanionOnly = $true }
        }
        if ($same.Return) {
            return @{ Return = $true; Result = $same.Result; CompanionOnly = $false }
        }
    } elseif ($cmpAfterPackage -gt 0) {
        return (Complete-WinstInstallSkip -Result $Result -Version $Detected `
            -Message ('{0} 本机已安装 {1}，比软件源里的 {2} 更新{3}' -f $DisplayName, $Detected, $Version, (Get-WinstForceHint -Kind 'downgrade')))
    } elseif (-not $Quiet) {
        Write-Host ('  发现新版本：已安装 {0}  →  {1}  ↑' -f $Detected, $Version) -ForegroundColor Green
    }

    return @{ Return = $false; Result = $null; CompanionOnly = $companionOnlyUpdate }
}
