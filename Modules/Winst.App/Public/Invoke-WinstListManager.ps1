#Requires -Version 5.1

function Invoke-WinstListManager {
    <#
    .SYNOPSIS
        「高级功能 → 管理安装清单」：直接列出全部安装清单，输入编号查看 / 编辑 / 删除，
        输入文件名新建（与「管理软件源」同一形态，没有单独的「查看」菜单项）。
    .DESCRIPTION
        ① 每轮先渲染清单列表（编号 = Show-WinstListManagerMenu 返回的顺序）；
        ② 编号 → 先逐项显示清单内容，再给 e 编辑 / d 删除 / 回车（或 b）返回；
        ③ 文件名 → 新建清单（已存在则进入编辑）；
        ④ 回车 / b 都返回上级，q 退出程序（与其它菜单一致）——回车不当「新建默认清单」。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context
    )

    $kindText = (Get-WinstListKindText)
    $pause = {
        Write-Host ''
        Read-WinstPause -Text '  按回车键返回列表…'

    }

    while ($true) {
        Clear-ScreenSafe
        $files = @(Show-WinstListManagerMenu -Context $Context)

        $answer = $null
        try { $answer = Read-Host '  请输入' } catch { $answer = $null }
        $text = ''
        if ($null -ne $answer) { $text = ([string]$answer).Trim() }

        # 回车与 b 同义：返回上一级（新建清单靠输入文件名，回车不等于「新建默认清单」）
        if (-not $text) { return }
        if ((Test-WinstQuitKey -Text $text)) { Set-WinstQuit; return }
        if ($text -ieq 'b') { return }

        # —— 输入编号：查看这份清单，随后可编辑 / 删除 ——
        $number = 0
        if ($text -and [int]::TryParse($text, [ref]$number)) {
            if ($files.Count -eq 0) {
                Write-Host ''
                Write-Host ('  现在还没有{0}，可直接输入文件名新建。' -f $kindText) -ForegroundColor Yellow
                & $pause
                continue
            }
            if ($number -lt 1 -or $number -gt $files.Count) {
                Write-Host ''
                Write-Host ('  没有这个编号（可选 1 - {0}），请重新输入；也可以直接输入文件名新建。' -f $files.Count) -ForegroundColor Yellow
                & $pause
                continue
            }

            $targetPath = [string]$files[$number - 1]['Path']
            $targetName = [string]$files[$number - 1]['Name']

            $null = Invoke-WinstListShow -Context $Context -Path $targetPath

            Write-Host ''
            Write-Host ('  e = 编辑这份清单，d = 删除，回车 / b = 返回列表（当前: {0}）' -f $targetName) -ForegroundColor DarkGray
            $sub = Read-Host '  请输入'
            $subText = ''
            if ($null -ne $sub) { $subText = ([string]$sub).Trim() }

            if ((Test-WinstQuitKey -Text $subText)) { Set-WinstQuit; return }
            if ($subText -ieq 'e') {
                Invoke-WinstListEditFlow -Context $Context -Path $targetPath
                if ((Get-WinstState -Name WinstQuitRequested)) { return }
                & $pause
                continue
            }
            if ($subText -ieq 'd') {
                $dryRun = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun)
                Write-Host ''
                if ($dryRun) {
                    Write-Host ('  （预览）将删除清单: {0}（--dry-run 不落盘）' -f $targetPath) -ForegroundColor DarkYellow
                } elseif (Read-WinstConfirm -Prompt ('  确定删除「{0}」？删除后无法恢复 (y/N)' -f $targetName) -Default 'n') {
                    try {
                        Remove-Item -LiteralPath $targetPath -Force -ErrorAction Stop
                        Write-Host ('  已删除: {0}' -f $targetPath) -ForegroundColor Green
                    } catch {
                        Write-Host ('  删除失败: {0}' -f $_.Exception.Message) -ForegroundColor Red
                    }
                } else {
                    Write-Host '  已取消：清单没有改动。' -ForegroundColor DarkGray
                }
                & $pause
                continue
            }

            # 回车 / 其它输入 = 回到清单列表
            continue
        }

        # —— 输入文件名：新建清单（已存在则进入编辑） ——
        $resolved = Resolve-WinstListPath -Context $Context -Text $text
        if (-not $resolved.Ok) {
            Write-Host ''
            Write-Host ('  {0}' -f $resolved.Error) -ForegroundColor Red
            & $pause
            continue
        }

        $newPath = [string]$resolved.Path
        if (Test-Path -LiteralPath $newPath -PathType Leaf) {
            Write-Host ''
            Write-Host ('  这份{0}已存在，直接进入编辑: {1}' -f $kindText, $newPath) -ForegroundColor Gray
        }
        Invoke-WinstListEditFlow -Context $Context -Path $newPath
        if ((Get-WinstState -Name WinstQuitRequested)) { return }
        & $pause
    }
}
