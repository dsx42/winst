#Requires -Version 5.1

function Add-WinstCompanionFiles {
    <#
    .SYNOPSIS
        配套文件按 dest 落位，并删除上次落位、这次不需要的旧文件（installer 的配套文件仅缓存）。
    .DESCRIPTION
        `-CompanionOnly`（主包无变化、只更新附加文件）：只做覆盖写入，**不删除**安装目录里的任何文件
        （含上次落位、这次不再声明的旧附件）——用户只要附件更新，不该顺手清掉别的东西。
        完整安装仍按老规则清理过期附件。
    .OUTPUTS
        @{ Error; Files; Rules; UpdatedNames; Removed; KeptDirs }
    #>
    param([hashtable]$Context, $Files, [string]$PkgDir, [string]$InstallDir, $Ledger, [string]$Method,
        [switch]$CompanionOnly, [switch]$Quiet, [string[]]$ChangedNames = @())

    $staleRemoved = @()
    $staleDirs = @()
    if ($Method -eq 'installer') {
        return @{ Error = ''; Files = @(); Rules = (New-WinstOrdinalDictionary); UpdatedNames = @(); Removed = @(); KeptDirs = @() }
    }

    $previousRules = Get-EntryValue -Entry $Ledger -Key 'appliedFileRules' -Default $null
    $landing = Copy-WinstCompanionFiles -Context $Context -Files $Files -PkgDir $PkgDir -InstallDir $InstallDir `
        -OnlyChanged:$CompanionOnly -ChangedNames $ChangedNames -PreviousRules $previousRules
    if (-not $landing.Ok) { return @{ Error = [string]$landing.Error; Files = @(); Removed = @(); KeptDirs = @() } }
    $appliedFiles = @($landing.Files)
    if ($CompanionOnly) {
        foreach ($previous in @(Get-EntryArray -Entry $Ledger -Key 'appliedFiles')) {
            if ($appliedFiles -notcontains [string]$previous) { $appliedFiles += [string]$previous }
        }
        return @{ Error = ''; Files = $appliedFiles; Rules = $landing.Rules; UpdatedNames = @($landing.UpdatedNames); Removed = @(); KeptDirs = @() }
    }

    $previousApplied = @()
    if ($Ledger) { $previousApplied = @(Get-EntryArray -Entry $Ledger -Key 'appliedFiles') }
    if (@($previousApplied).Count -gt 0) {
        $stale = Remove-WinstStaleCompanionFiles -InstallDir $InstallDir -PreviousFiles $previousApplied -CurrentFiles $appliedFiles
        $staleRemoved = @($stale.Removed)
        $staleDirs = @($stale.KeptDirs)
        foreach ($note in @($stale.Notes)) { Write-Host ('    提示: {0}' -f $note) -ForegroundColor DarkYellow }
        if ($staleRemoved.Count -gt 0 -and -not $Quiet) {
            Write-Host ('    已删除不再需要的旧附加文件: {0}' -f ($staleRemoved -join '、')) -ForegroundColor DarkGray
        }
        if ($staleDirs.Count -gt 0 -and -not $Quiet) {
            Write-Host ('    提示: 旧目录未自动删除（里面可能还有其它文件），需要时请手动清理: {0}' -f ($staleDirs -join '、')) -ForegroundColor DarkYellow
        }
    }
    return @{ Error = ''; Files = $appliedFiles; Rules = $landing.Rules; UpdatedNames = @($landing.UpdatedNames); Removed = $staleRemoved; KeptDirs = $staleDirs }
}
