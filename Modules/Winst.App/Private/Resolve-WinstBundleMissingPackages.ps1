#Requires -Version 5.1

function Resolve-WinstBundleMissingPackages {
    <#
    .SYNOPSIS
        ⑤ 缺包检查（只查本地缓存），按需联网补齐，并返回仍需跳过 / 源里没有的项。
    .OUTPUTS
        @{ NeedDownload; NoSource; Downloaded }
    #>
    param([hashtable]$Context, $Plan, $Lookup, [switch]$Offline, [switch]$DryRun, [switch]$SkipMissing,
        [bool]$Yes = $false, [switch]$NonInteractive)

    $needDownload = @()
    $noSource = @()
    foreach ($entry in @($Plan)) {
        $item = $entry['Item']
        if ([bool]$item['CacheHas']) { continue }
        if (-not [bool]$item['InCatalog']) { $noSource += $item; continue }
        # 有条目但没有可用版本（清单有误 / 全部来源不可用）→ 无法补齐，直接归入「源里没有可用版本」
        if (-not [string]$item['BestVersion']) { $noSource += $item; continue }
        $needDownload += $item
    }

    $downloaded = 0
    if ($needDownload.Count -gt 0) {
        Write-Host ''
        Write-Host ('  以下 {0} 个软件本地还没有已下载的安装包：' -f $needDownload.Count) -ForegroundColor Yellow
        foreach ($item in $needDownload) {
            Write-Host ('    - {0}（{1}）' -f [string]$item['DisplayName'], [string]$item['Id']) -NoNewline -ForegroundColor DarkYellow
            if ([string]$item['BestVersion']) { Write-Host ('    软件源里 {0}' -f [string]$item['BestVersion']) -ForegroundColor DarkGray }
            else { Write-Host '    软件源里没有可用的版本信息' -ForegroundColor DarkGray }
        }

        $doDownload = $false
        if ($Offline) {
            Write-Host '  当前为离线模式，不会联网补齐，这些软件会被跳过。' -ForegroundColor DarkYellow
        } elseif ($DryRun) {
            Write-Host '  当前为预览模式（--dry-run），不会联网补齐，这些软件会被跳过。' -ForegroundColor DarkYellow
        } elseif ($SkipMissing) {
            Write-Host '  已指定 --skip-missing，不联网补齐，这些软件会被跳过。' -ForegroundColor DarkYellow
        } elseif ($Yes) {
            $doDownload = $true
        } elseif ($NonInteractive -or (Test-WinstInputRedirected)) {
            Write-Host '  当前为非交互运行，不会联网补齐，这些软件会被跳过。' -ForegroundColor DarkYellow
        } else {
            if (Read-WinstConfirm -Prompt '  是否现在联网下载补齐？(y/N，n = 跳过这些软件继续制作)' -Default 'n') { $doDownload = $true }
        }

        if ($doDownload) {
            Write-Host ''
            Write-Host '  正在下载补齐（每个软件的动作会逐条打印）…' -ForegroundColor Gray
            foreach ($item in $needDownload) {
                $chosen = Get-WinstRowBestPlanEntry -Row $item['Row']
                if (-not $chosen) {
                    Write-Host ('  {0}: 已跳过：软件源里没有可用的版本信息。' -f [string]$item['DisplayName']) -ForegroundColor DarkYellow
                    continue
                }
                Write-Host ''
                Write-Host ('  —— {0} 下载 {1}（来自 {2}）——' -f [string]$item['DisplayName'], [string]$chosen['Version'], [string]$chosen['Source']) -ForegroundColor Cyan
                $one = Invoke-WinstAppInstall -Context $Context -Plan $chosen['Plan'] -SourceName ([string]$chosen['Source']) -DownloadOnly -Quiet
                if ($one.Ok) {
                    $downloaded++
                    if ($one.Message) { Write-Host ('  {0}' -f $one.Message) -ForegroundColor Green }
                } else {
                    $reason = [string]$one.Error
                    if (-not $reason) { $reason = [string]$one.Message }
                    Write-Host ('  失败: {0}' -f $reason) -ForegroundColor Red
                }
            }
            # 下载后再判定一次：仍缺包的计入「跳过」
            $freshLookup = Get-WinstListLookups -Context $Context
            if (-not $freshLookup.Ok) { throw ('下载后读取缓存失败：{0}' -f $freshLookup.Error) }
            $Lookup = $freshLookup
            $stillMissing = @()
            foreach ($item in $needDownload) {
                if ([bool]$item['CacheHas']) { continue }
                $recheck = New-WinstListItem -Context $Context -Id ([string]$item['Id']) -PinnedVersion ([string]$item['PinnedVersion']) -Lookup $Lookup
                if ([bool]$recheck['CacheHas']) { continue }
                $stillMissing += $item
            }
            $needDownload = @($stillMissing)
        }

        if ($needDownload.Count -gt 0) {
            Write-Host ''
            Write-Host ('  将跳过 {0} 个缺包项（套件里不会有它们，目标机器安装时会尝试联网下载）。' -f $needDownload.Count) -ForegroundColor DarkYellow
        }
    }

    if ($noSource.Count -gt 0) {
        Write-Host ''
        Write-Host ('  以下 {0} 个软件在软件源里没有可用版本（没有定义 / 清单有误），将跳过：' -f $noSource.Count) -ForegroundColor DarkYellow
        foreach ($item in $noSource) {
            Write-Host ('    - {0}（{1}）' -f [string]$item['DisplayName'], [string]$item['Id']) -ForegroundColor DarkYellow
        }
    }

    return @{ NeedDownload = $needDownload; NoSource = $noSource; Downloaded = $downloaded }
}
