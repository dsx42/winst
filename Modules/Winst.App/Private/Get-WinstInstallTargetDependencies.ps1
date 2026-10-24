#Requires -Version 5.1

function Get-WinstInstallTargetDependencies {
    <#
    .SYNOPSIS
        解析传递依赖里需要动作的部分（未安装 / 可更新），并打印缺失与汇总提示。
    .OUTPUTS
        @{ Steps; Missing }
    #>
    param([hashtable]$Context, $Plan, [string]$PlanId, $State, [switch]$SkipDependencies, [switch]$IsDownloadPlan)

    $depSteps = @()
    $depMissing = @()
    # 仅下载类型不安装到电脑，依赖对它无意义，因此不处理；依赖自身的安装用 -SkipDependencies 复用本函数。
    if (-not $SkipDependencies -and -not $IsDownloadPlan) {
        $depDeclared = @(Get-EntryArray -Entry $Plan -Key 'dependencies')
        if ($depDeclared.Count -gt 0 -and $PlanId) {
            $resolvedDeps = Resolve-WinstDependencyOrder -Context $Context -Id $PlanId
            if (-not $resolvedDeps.Ok) {
                Write-Host ('    提示: 无法解析依赖（{0}），本次只处理本体。' -f $resolvedDeps.Error) -ForegroundColor DarkYellow
            } else {
                $depMissing = @($resolvedDeps.Missing)
                $depIndex = Get-WinstDependencyIndex -Context $Context
                $stateForDeps = $State
                if ($null -eq $stateForDeps) { $stateForDeps = (Read-WinstState -InstallRoot $Context.InstallRoot).State }
                foreach ($one in @($resolvedDeps.Order)) {
                    $depId = [string]$one['Id']
                    $depRow = $null
                    if ($depIndex['Rows'].Contains($depId)) { $depRow = $depIndex['Rows'][$depId] }
                    $depEntry = $null
                    if ($depRow) { $depEntry = Get-WinstRowBestSourceEntry -Row $depRow }
                    if (-not $depEntry -or -not $depEntry['Plan']) {
                        $depMissing += @{ Id = $depId; Level = [int]$one['Level']; Via = [string]$one['Via'] }
                        continue
                    }

                    $depLedger = Get-WinstInstalledApp -State $stateForDeps -Id $depId
                    $depInstalledVersion = ''
                    if ($depLedger) { $depInstalledVersion = Get-EntryString -Entry $depLedger -Key 'version' }
                    $depTargetVersion = [string]$depEntry['Version']
                    $depActionText = ''
                    if (-not $depInstalledVersion) {
                        $depActionText = '未安装'
                    } elseif ($depTargetVersion -and ((Compare-WinstVersion -A $depTargetVersion -B $depInstalledVersion) -gt 0)) {
                        $depActionText = ('可更新到 {0}' -f $depTargetVersion)
                    }
                    if (-not $depActionText) { continue }   # 已安装且已是最新：不提示、不处理

                    $depName = [string]$depRow['Name']
                    if (-not $depName) { $depName = $depId }
                    $depSteps += @{
                        Id               = $depId
                        Name             = $depName
                        Row              = $depRow
                        Level            = [int]$one['Level']
                        Via              = [string]$one['Via']
                        ActionText       = $depActionText
                        InstalledVersion = $depInstalledVersion
                        TargetVersion    = $depTargetVersion
                    }
                }
            }
        }
    }

    foreach ($miss in @($depMissing)) {
        Write-Host ('    提示: 依赖「{0}」在软件源里不存在，已跳过（不影响本体的安装）。' -f [string]$miss['Id']) -ForegroundColor DarkYellow
    }
    if ($depSteps.Count -gt 0) {
        $depParts = @()
        foreach ($step in @($depSteps)) {
            $depParts += ('{0}（{1}）' -f [string]$step['Name'], [string]$step['ActionText'])
        }
        Write-Host ('    依赖: 将一并处理 {0}' -f ($depParts -join '、')) -ForegroundColor DarkYellow
    }
    return @{ Steps = @($depSteps); Missing = @($depMissing) }
}
