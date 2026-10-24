#Requires -Version 5.1

function Add-WinstCompanionFiles {
    <#
    .SYNOPSIS
        配套文件按 dest 落位，并删除上次落位、这次不需要的旧文件（installer 的配套文件仅缓存）。
    .OUTPUTS
        @{ Error; Files; Removed; KeptDirs }
    #>
    param([hashtable]$Context, $Files, [string]$PkgDir, [string]$InstallDir, $Ledger, [string]$Method, [switch]$Quiet)

    $staleRemoved = @()
    $staleDirs = @()
    if ($Method -eq 'installer') {
        return @{ Error = ''; Files = @(); Removed = @(); KeptDirs = @() }
    }

    $landing = Copy-WinstCompanionFiles -Context $Context -Files $Files -PkgDir $PkgDir -InstallDir $InstallDir
    if (-not $landing.Ok) { return @{ Error = [string]$landing.Error; Files = @(); Removed = @(); KeptDirs = @() } }
    $appliedFiles = @($landing.Files)

    $previousApplied = @()
    if ($Ledger) { $previousApplied = @(Get-EntryArray -Entry $Ledger -Key 'appliedFiles') }
    if (@($previousApplied).Count -gt 0) {
        $stale = Remove-WinstStaleCompanionFiles -InstallDir $InstallDir -PreviousFiles $previousApplied -CurrentFiles $appliedFiles
        $staleRemoved = @($stale.Removed)
        $staleDirs = @($stale.KeptDirs)
        if ($staleRemoved.Count -gt 0 -and -not $Quiet) {
            Write-Host ('    已删除不再需要的旧附加文件: {0}' -f ($staleRemoved -join '、')) -ForegroundColor DarkGray
        }
        if ($staleDirs.Count -gt 0 -and -not $Quiet) {
            Write-Host ('    提示: 旧目录未自动删除（里面可能还有其它文件），需要时请手动清理: {0}' -f ($staleDirs -join '、')) -ForegroundColor DarkYellow
        }
    }
    return @{ Error = ''; Files = $appliedFiles; Removed = $staleRemoved; KeptDirs = $staleDirs }
}
