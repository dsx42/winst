#Requires -Version 5.1

function Invoke-WinstBundleInstallRun {
    <#
    .SYNOPSIS
        按安装清单条目逐个安装（菜单「一键安装」与 CLI `bundle install` 共用）。
    .OUTPUTS
        @{ OkCount; DownloadOkCount; SkipCount; MissingCount; PinSkipped; CancelCount; FailCount }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][array]$Items,
        [switch]$InstallYes,
        [switch]$PinAutoContinue,
        [switch]$SkipExisting,
        [ValidateSet('Menu', 'Cli')]
        [string]$Presentation = 'Menu'
    )

    $stats = @{
        OkCount           = 0
        DownloadOkCount   = 0
        SkipCount         = 0
        MissingCount      = 0
        PinSkipped        = 0
        CancelCount       = 0
        FailCount         = 0
    }

    foreach ($item in @($Items)) {
        $id = [string]$item['Id']
        $name = [string]$item['DisplayName']

        if (-not [bool]$item['InCatalog']) {
            $stats['MissingCount']++
            if ($Presentation -eq 'Cli') {
                Write-Host ('  {0}（{1}）: 已跳过：软件源里没有这个软件。' -f $name, $id) -ForegroundColor DarkYellow
            } else {
                Write-Host ''
                Write-Host ('  —— {0}（{1}）——' -f $name, $id) -ForegroundColor Cyan
                Write-Host '  已跳过：软件源里没有这个软件（可到「高级功能 → 管理软件源」刷新后再试）。' -ForegroundColor DarkYellow
            }
            continue
        }
        if (-not (Get-WinstRowBestPlanEntry -Row $item['Row'])) {
            $stats['MissingCount']++
            if ($Presentation -eq 'Cli') {
                Write-Host ('  {0}（{1}）: 已跳过：软件源里没有可用的版本信息。' -f $name, $id) -ForegroundColor DarkYellow
            } else {
                Write-Host ''
                Write-Host ('  —— {0}（{1}）——' -f $name, $id) -ForegroundColor Cyan
                Write-Host '  已跳过：软件源里没有可用的版本信息（可到「高级功能 → 管理软件源」刷新后再试）。' -ForegroundColor DarkYellow
            }
            continue
        }
        if ($SkipExisting -and [bool]$item['Installed']) {
            $stats['SkipCount']++
            Write-Host ('  {0}（{1}）: 已安装 {2}，按 --skip-existing 跳过。' -f $name, $id, [string]$item['InstalledVersionText']) -ForegroundColor DarkGray
            continue
        }

        Write-Host ''
        Write-Host ('  —— {0}（{1}）——' -f $name, $id) -ForegroundColor Cyan

        if ([string]$item['PinnedVersion'] -and ([bool]$item['PinMismatch'] -or [bool]$item['PinUnknown'])) {
            $note = Get-WinstListItemPinNote -Item $item
            if ($note.Text) { Write-Host ('  提示: {0}' -f [string]$note.Text) -ForegroundColor DarkYellow }
            if ($Presentation -eq 'Menu') {
                if ($PinAutoContinue) {
                    Write-Host '  已按软件源里的版本继续。' -ForegroundColor DarkGray
                } elseif (-not (Read-WinstConfirm -Prompt '  按软件源里的版本安装？(Y/n，n = 跳过这一项)' -Default 'y')) {
                    $stats['PinSkipped']++
                    Write-Host '  已跳过：软件源里的版本和清单里写的不一致，这一项没有装。' -ForegroundColor DarkGray
                    continue
                }
            }
        }

        $one = Invoke-WinstInstallTarget -Context $Context -Row $item['Row'] -AutoPickSource -Yes:$InstallYes
        if ($one.Cancelled) {
            if ($Presentation -eq 'Menu') { $stats['CancelCount']++ } else { $stats['FailCount']++ }
            continue
        }
        if (-not $one.Ok) {
            $stats['FailCount']++
            if ($one.Error) { Write-Host ('  失败: {0}' -f [string]$one.Error) -ForegroundColor Red }
            elseif ([string]$one.Message) { Write-Host ('  失败: {0}' -f [string]$one.Message) -ForegroundColor Red }
            else { Write-Host '  失败: 安装流程没有给出原因（可用 --verbose 重试以取得更多信息）。' -ForegroundColor Red }
            continue
        }
        if ($one.Skipped) { $stats['SkipCount']++; continue }
        $stats['OkCount']++
        if ((Get-WinstRowType -Row $item['Row']) -eq 'download') { $stats['DownloadOkCount']++ }
    }

    return $stats
}
