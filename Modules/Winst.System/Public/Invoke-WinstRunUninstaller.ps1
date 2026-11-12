#Requires -Version 5.1

function Invoke-WinstRunUninstaller {
    <#
    .SYNOPSIS
        按名称规则卸载全部匹配记录；每次执行前通过单键入口实时回读。
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context, [Parameter(Mandatory = $true)]$Plan, [switch]$Quiet)

    $result = @{ Ok=$false; Missing=$false; Cancelled=$false; NeedRestart=$false; RestartInitiated=$false; Error=''; Command=''; ExitCode=0 }
    $status = @{}
    $hits = @(Get-WinstRegistryEntriesForPlan -Plan $Plan -Status $status | Where-Object {
        [string]$_['UninstallString']
    } | Sort-Object @{Expression={Test-WinstRegistryEntryIsMsi -Entry $_}}, @{Expression={[string]$_['DisplayName']}})
    if (-not $status.Ok) { $result.Error = $status.Error; return $result }
    if ($hits.Count -eq 0) { $result.Missing=$true; $result.Error='系统安装记录里没有找到这个软件的卸载程序'; return $result }
    $extraArgs = Get-EntryString -Entry (Get-EntryValue $Plan 'uninstall') -Key 'uninstallArgs'
    $ran = 0
    $orphans = @()
    foreach ($hit in $hits) {
        $run = Invoke-WinstUninstallRegistryKey -KeyPath ([string]$hit['KeyPath']) -ExtraArgs $extraArgs -Quiet:$Quiet
        if ($run.Missing) { $orphans += [string]$hit['KeyPath']; continue }
        $result.Command = $run.Command
        $result.ExitCode = $run.ExitCode
        if (-not $run.Ok) { $result.Error=$run.Error; $result.Cancelled=$run.Cancelled; return $result }
        $ran++
        if ($run.NeedRestart) { $result.NeedRestart=$true }
        if ($run.RestartInitiated) { $result.RestartInitiated=$true; $result.Ok=$true; return $result }
    }
    if ($ran -eq 0) { $result.Error='没有可用的卸载器；如已手动卸载，可加 --force 只移除安装记录'; return $result }
    foreach ($keyPath in $orphans) {
        $clean = Remove-WinstOrphanRegistryRecord -KeyPath $keyPath -Quiet:$Quiet
        if ($clean.Error -and -not $Quiet) { Write-Host ('    提示: ' + $clean.Error) -ForegroundColor DarkYellow }
    }
    $result.Ok=$true
    return $result
}
