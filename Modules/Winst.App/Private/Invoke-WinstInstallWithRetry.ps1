#Requires -Version 5.1

function Invoke-WinstInstallWithRetry {
    <#
    .SYNOPSIS
        调安装流程；被「已装同版本 / 其它版本」跳过时，交互式下再问一次是否强制重装。
    .OUTPUTS
        @{ Install; SkipReasonShown }
    #>
    param([hashtable]$Context, $Plan, [string]$SourceName, [bool]$ForceInstall, [switch]$Overwrite,
        [string[]]$Keep = @(), [switch]$DownloadOnly, [switch]$KillRunning, [switch]$Quiet,
        [switch]$FilesOnly, [switch]$ForceSystemItems, [switch]$Yes, [switch]$DownloadMode)

    $install = Invoke-WinstAppInstall -Context $Context -Plan $Plan -SourceName $SourceName `
        -Force:$ForceInstall -Overwrite:$Overwrite -Keep $Keep -DownloadOnly:$DownloadOnly -KillRunning:$KillRunning -Quiet:$Quiet `
        -FilesOnly:$FilesOnly -ForceSystemItems:$ForceSystemItems

    $skipReasonShown = $false
    if ($install.Skipped -and -not $Yes -and -not $DownloadMode -and -not $ForceInstall) {
        Write-Host ''
        Write-Host ('  已跳过：{0}' -f $install.Message) -ForegroundColor DarkYellow
        $skipReasonShown = $true
        if (Read-WinstConfirm -Prompt '  是否强制重装（忽略上面的检查，覆盖安装）？(y/N)' -Default 'n') {
            $install = Invoke-WinstAppInstall -Context $Context -Plan $Plan -SourceName $SourceName `
                -Force -Overwrite:$Overwrite -Keep $Keep -DownloadOnly:$DownloadOnly -KillRunning:$KillRunning -Quiet:$Quiet `
                -FilesOnly:$FilesOnly -ForceSystemItems:$ForceSystemItems
            $skipReasonShown = $false
        }
    }
    return @{ Install = $install; SkipReasonShown = $skipReasonShown }
}
