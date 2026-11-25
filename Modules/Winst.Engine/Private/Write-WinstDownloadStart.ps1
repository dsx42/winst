#Requires -Version 5.1

function Write-WinstDownloadStart {
    param([string]$FileName, [string]$SizeText, [string]$Mode, [switch]$Resume, [switch]$Quiet)

    if ($Quiet) { return }
    $action = '下载'
    if ($Resume) { $action = '续传' }
    Write-Host ('    正在{0} {1}（{2}）｜{3}' -f $action, $FileName, $SizeText, $Mode) -ForegroundColor Gray
}
