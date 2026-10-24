#Requires -Version 5.1

function Invoke-WinstInstallCommand {
    <#
    .SYNOPSIS
        CLI：winst install / download <id>...（下载统一走 FluxDown CLI，先展示执行计划再执行）。
    .OUTPUTS
        [int] 退出码：0 成功 / 1 参数错误 / 2 网络失败 / 3 安装失败
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string[]]$Arguments = @(),
        [switch]$DownloadOnly
    )

    $commandName = 'install'
    if ($DownloadOnly) { $commandName = 'download' }

    $ids = @()
    $force = $false
    $overwrite = $false
    $keep = @()
    $kill = $false
    $filesOnly = $false
    $forceSystemItems = $false
    $sourceName = ''
    $fromPath = ''
    $yes = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Yes)

    # 带值开关（--source / --keep / --from）：值就地消费，不会把与取值同名的 id 一起收下，
    # 也能发现「开关没给值」
    $pendingValue = ''
    foreach ($token in @($Arguments)) {
        $text = [string]$token

        if ($pendingValue) {
            if (-not $text -or $text.StartsWith('-')) {
                # 下一个 token 是开关（如 `install x --keep --force`）：不能把它当成取值吞掉，
                # 提示后让当前 token 继续按开关解析
                $missingName = '--source'
                if ($pendingValue -eq 'keep') { $missingName = '--keep' }
                if ($pendingValue -eq 'from') { $missingName = '--from' }
                Write-Host ('  参数缺少取值：{0}（已忽略）' -f $missingName) -ForegroundColor Yellow
                $pendingValue = ''
            } else {
                if ($pendingValue -eq 'source') {
                    $sourceName = $text.Trim()
                } elseif ($pendingValue -eq 'from') {
                    $fromPath = $text.Trim()
                } else {
                    $keep = @($text -split '[,，]' | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
                }
                $pendingValue = ''
                continue
            }
        }

        if ($text -eq '--force') { $force = $true }
        elseif ($text -eq '--overwrite') { $overwrite = $true }
        elseif ($text -eq '--kill') { $kill = $true }
        elseif ($text -eq '--files-only') { $filesOnly = $true }
        elseif ($text -eq '--system-items') { $forceSystemItems = $true }
        elseif ($text -eq '--source') { $pendingValue = 'source' }
        elseif ($text.StartsWith('--source=')) { $sourceName = ($text.Substring(9)).Trim() }
        elseif ($text -eq '--from') { $pendingValue = 'from' }
        elseif ($text.StartsWith('--from=')) { $fromPath = ($text.Substring(7)).Trim() }
        elseif (Try-Apply-WinstCommonCliFlag -Text $text -Yes ([ref]$yes)) { }
        elseif ($text -eq '--keep') { $pendingValue = 'keep' }
        elseif ($text.StartsWith('--keep=')) {
            $keep = @(($text.Substring(7)) -split '[,，]' | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
        } elseif ($text.StartsWith('-')) {
            Write-Host ''
            Write-Host ('  未知参数: {0}' -f $text) -ForegroundColor Yellow
            return 1
        } else {
            $ids += $text
        }
    }

    # 开关写在末尾、没给值：明确报错，不静默按默认来源 / 不保留任何文件
    if ($pendingValue) {
        $missing = '--source'
        if ($pendingValue -eq 'keep') { $missing = '--keep' }
        if ($pendingValue -eq 'from') { $missing = '--from' }
        Write-Host ''
        Write-Host ('  {0} 缺少取值，请写成 {0} <值> 或 {0}=<值>。' -f $missing) -ForegroundColor Yellow
        return 1
    }

    # ---------------------------------------------------------------- 本地包
    # 从本地包（release zip 或已解压目录）安装 winst 自身。
    # 这里刻意短路掉下面全部流程：
    #
    #   - 不查软件源        全新机器还没有刷新过的源
    #   - 不解析依赖        解压一个 zip 不需要引擎
    #   - 不下载            包已经在磁盘上
    #
    # 这样就不会出现「装 winst 需要先能访问软件源」的自锁，
    # 而首次安装恰恰没有可访问的源。主要调用方是一行安装脚本 install.ps1。
    if ($fromPath) {
        if ($ids.Count -ne 1 -or ([string]$ids[0]).Trim() -ine 'winst') {
            Write-Host ''
            Write-Host '  --from 目前只支持安装 winst 自身：' -ForegroundColor Yellow
            Write-Host '    winst install winst --from <winst.zip 或解压后的目录>' -ForegroundColor Gray
            return 1
        }
        if ($DownloadOnly) {
            Write-Host ''
            Write-Host '  --from 是本地安装包，没有可下载的内容；请用 winst install。' -ForegroundColor Yellow
            return 1
        }

        # --from 走的是自安装路径，除 --force 外的安装类开关都不适用。
        # 明说一句，避免使用者以为 --keep 之类已经生效。
        $ignored = @()
        if ($overwrite) { $ignored += '--overwrite' }
        if (@($keep).Count -gt 0) { $ignored += '--keep' }
        if ($filesOnly) { $ignored += '--files-only' }
        if ($forceSystemItems) { $ignored += '--system-items' }
        if ($sourceName) { $ignored += '--source' }
        if ($ignored.Count -gt 0) {
            Write-Host ''
            Write-Host ('  提示: 本地自安装不适用 {0}，已忽略。' -f ($ignored -join ' / ')) -ForegroundColor DarkYellow
        }

        Write-Section ('{0} {1}' -f $commandName, 'winst')

        $selfResult = Install-WinstSelf -Context $Context -FromPath $fromPath -ForceUpdate:$force

        Write-Host ''
        if (-not $selfResult.Ok) {
            Write-Host ('  汇总: 成功 0 / 跳过 0 / 失败 1' ) -ForegroundColor Yellow
            Write-Host ('  {0}' -f $selfResult.Error) -ForegroundColor Red
            return 3
        }

        if ($selfResult.UpToDate) {
            Write-Host '  汇总: 成功 0 / 跳过 1 / 失败 0' -ForegroundColor Gray
        } else {
            Write-Host '  汇总: 成功 1 / 跳过 0 / 失败 0' -ForegroundColor Gray
        }
        return 0
    }

    if ($ids.Count -eq 0) {
        Write-Host ''
        Write-Host ('  用法: winst {0} <id> [<id>...]' -f $commandName) -ForegroundColor Yellow
        Write-Host ('  示例: winst {0} jdk21 Rufus' -f $commandName) -ForegroundColor Gray
        Write-Host '  可选参数: --force（相同版本也重装 / 降级）/ --overwrite / --keep a,b / --kill（结束正在运行的该软件）/ --yes' -ForegroundColor Gray
        Write-Host '            --files-only（仅更新文件：不动环境变量 / PATH / 快捷方式；首次安装时也不补，比默认更彻底）' -ForegroundColor Gray
        Write-Host '            --system-items（完整更新：覆盖已存在的环境变量 / 快捷方式）' -ForegroundColor Gray
        Write-Host '            --source <名称>（指定软件源）' -ForegroundColor Gray
        Write-Host '            --from <路径>（从本地 winst 安装包安装 winst 自身：zip 或解压目录；不走软件源、不联网）' -ForegroundColor Gray
        Write-Host '  说明: 软件源里是更新版本时直接按更新安装（无需 --force）；只有版本相同时才会跳过。' -ForegroundColor Gray
        Write-Host '  说明: 「仅下载软件包」类型的软件只下载到安装包位置（等同 winst download），不安装到电脑；--force / --overwrite / --keep 对它不适用。' -ForegroundColor Gray
        Write-Host '  说明: 软件声明了依赖（dependencies）时，会先把依赖里未安装 / 可更新的部分安装 / 更新，再装这个软件（统一确认一次）。' -ForegroundColor Gray
        return 1
    }

    $null = Update-WinstDisplaySources -Context $Context -Ids $ids -Quiet

    $okCount = 0
    $downloadOkCount = 0   # 仅下载类型：软件包下载成功（不写台账，汇总里单列）
    $skipCount = 0
    $failCount = 0
    $networkFailed = $false
    $parameterFailed = $false

    # id → 清单行 的索引一次建好：避免每个 id 都做一次全量子串扫描，
    # 也避免 N 个 id 各留一份全量缓存常驻。
    # 用 Ordinal（区分大小写）字典，与 id 精确匹配语义一致。
    $rowById = Get-WinstCatalogRowMap -Context $Context

    # 台账读一次：循环里只做 Get-WinstInstalledApp 查表，避免每个 id 重解析 state.json
    $state = (Read-WinstState -InstallRoot $Context.InstallRoot).State

    foreach ($id in $ids) {
        Write-Section ('{0} {1}' -f $commandName, $id)

        $row = $null
        if ($rowById.Contains($id)) { $row = $rowById[$id] }
        if (-not $row) {
            Write-Host ('  软件源里没有找到「{0}」这个软件。' -f $id) -ForegroundColor Yellow
            $parameterFailed = $true
            $failCount++
            continue
        }

        # 来源：默认按「本地清单 → 内置源 → 其它按添加顺序」；--source 指定时优先它。
        # 已安装的软件优先用「有更新版本」的来源，避免选到更旧的来源而变成「无更新可做」。
        $installedVersion = ''
        $ledger = Get-WinstInstalledApp -State $state -Id $id
        if (-not $ledger) {
            # 循环里可能刚装过（如前面某个 id 的依赖就是它）：缓存台账里查不到时重读一次，
            # 否则会漏掉「本机已装」而按默认来源排序、把已装软件当成首次安装来提示
            $state = (Read-WinstState -InstallRoot $Context.InstallRoot).State
            $ledger = Get-WinstInstalledApp -State $state -Id $id
        }
        if ($ledger) { $installedVersion = Get-EntryString -Entry $ledger -Key 'version' }
        $targetRow = Sort-WinstRowSources -Context $Context -Row $row -InstalledVersion $installedVersion
        if ($sourceName) {
            $preferred = Set-WinstRowPreferredSource -Row $targetRow -SourceName $sourceName
            if (([string]$preferred['Sources'][0]['Source']) -ieq $sourceName) {
                $targetRow = $preferred
            } else {
                Write-Host ('  提示: 软件源「{0}」里没有 {1} 的可用版本，已改用默认来源。' -f $sourceName, $id) -ForegroundColor DarkYellow
            }
        }

        $one = Invoke-WinstInstallTarget -Context $Context -Row $targetRow -Force:$force -Overwrite:$overwrite `
            -Keep $keep -DownloadOnly:$DownloadOnly -Yes:$yes -AutoPickSource:([bool]($yes -or $sourceName)) -KillRunning:$kill `
            -FilesOnly:$filesOnly -ForceSystemItems:$forceSystemItems
        if ($one.Cancelled) { $skipCount++; continue }
        if (-not $one.Ok) {
            if ($one.Network) { $networkFailed = $true }
            $failCount++
            continue
        }
        if ($one.Skipped) { $skipCount++; continue }
        $okCount++
        if ((Get-WinstRowType -Row $targetRow) -eq 'download') { $downloadOkCount++ }
    }

    Write-Host ''
    $summaryParts = @(('成功 {0}' -f $okCount))
    if ($downloadOkCount -gt 0) { $summaryParts += ('其中已下载软件包 {0}' -f $downloadOkCount) }
    $summaryParts += @(('跳过 {0}' -f $skipCount), ('失败 {0}' -f $failCount))
    Write-Host ('  汇总: {0}' -f ($summaryParts -join ' / ')) -ForegroundColor $(if ($failCount -gt 0) { 'Yellow' } else { 'Gray' })

    if ($failCount -gt 0) {
        if ($networkFailed) { return 2 }
        if ($okCount -gt 0) { return 3 }
        if ($parameterFailed) { return 1 }
        return 3
    }
    return 0
}
