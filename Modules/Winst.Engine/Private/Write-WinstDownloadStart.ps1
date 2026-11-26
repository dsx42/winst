#Requires -Version 5.1

function Write-WinstDownloadStart {
    param([string]$FileName, [string]$SizeText, [string]$Mode, [switch]$Resume, [switch]$Quiet)

    if ($Quiet) { return }
    $action = '下载'
    if ($Resume) { $action = '续传' }
    Write-Host ('    [{0}] 正在{1} {2}（{3}）｜{4}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $action, $FileName, $SizeText, $Mode) -ForegroundColor Gray
}
