#Requires -Version 5.1

function Invoke-ManifestCommand {
    <#
    .SYNOPSIS
        CLI：winst manifest add|list|update|remove 的参数解析与分发。
    .OUTPUTS
        [int] 退出码：0 成功 / 1 参数或业务错误 / 2 网络失败
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string[]]$Arguments = @()
    )

    $tokens = @()
    if ($Arguments) { $tokens = @($Arguments) }

    if ($tokens.Count -eq 0) {
        Write-Host ''
        Write-Host '  用法: winst manifest <add|list|update|remove>' -ForegroundColor Yellow
        Write-Host '    manifest add <仓库|地址>          添加 GitHub 仓库软件源（名称自动取 用户名/仓库）' -ForegroundColor Gray
        Write-Host '    manifest list                    列出全部软件源（含本地清单）' -ForegroundColor Gray
        Write-Host '    manifest update [<名称>|--all]    刷新软件源（本地清单也走同样流程）' -ForegroundColor Gray
        Write-Host '    manifest remove <名称>            删除软件源' -ForegroundColor Gray
        Write-Host '  示例: winst manifest add owner/repo' -ForegroundColor DarkGray
        Write-Host '        winst manifest add https://github.com/owner/repo' -ForegroundColor DarkGray
        Write-Host '        winst manifest add https://raw.githubusercontent.com/owner/repo/main/manifest.json' -ForegroundColor DarkGray
        Write-Host '  提示: 把清单文件放在脚本同目录（manifest.json 或 manifests\*.json）即作为本地清单自动生效，无需添加。' -ForegroundColor DarkGray
        return 1
    }

    $sub = ([string]$tokens[0]).ToLowerInvariant()
    $rest = @()
    if ($tokens.Count -gt 1) { $rest = @($tokens[1..($tokens.Count - 1)]) }

    # 子命令之后也可写通用开关（与 Read-WinstCommandLine 写在命令前/后等价）
    $parsed = Split-WinstSubcommandRestTokens -Rest $rest -IncludeAll
    $offline = [bool]$parsed.Offline
    $all = [bool]$parsed.All
    $positional = @($parsed.Positional)

    $null = Ensure-OfficialManifest -Context $Context

    if ($sub -eq 'list') {
        Invoke-ManifestList -Context $Context
        return 0
    }

    if ($sub -eq 'add') {
        if ($positional.Count -ne 1) {
            Write-Host ''
            Write-Host '  用法: winst manifest add <仓库|地址>' -ForegroundColor Yellow
            Write-Host '  示例: winst manifest add owner/repo' -ForegroundColor Gray
            Write-Host '        winst manifest add https://github.com/owner/repo' -ForegroundColor Gray
            Write-Host '        winst manifest add https://raw.githubusercontent.com/owner/repo/main/manifest.json' -ForegroundColor Gray
            return 1
        }
        $result = Add-RemoteManifest -Context $Context -RepoOrUrl $positional[0]
        Write-Host ''
        if ($result.Success) {
            Write-Host ('  {0}' -f $result.Message) -ForegroundColor Green
            return 0
        }
        Write-Host ('  {0}' -f $result.Message) -ForegroundColor Yellow
        return 1
    }

    if ($sub -eq 'remove') {
        if ($positional.Count -ne 1) {
            Write-Host ''
            Write-Host '  用法: winst manifest remove <name>' -ForegroundColor Yellow
            return 1
        }
        if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun) {
            Write-Host ''
            Write-Host ('  （预览）将删除软件源 "{0}"' -f $positional[0]) -ForegroundColor Cyan
            return 0
        }
        $result = Remove-RemoteManifest -Context $Context -Name $positional[0]
        Write-Host ''
        if ($result.Success) {
            Write-Host ('  {0}' -f $result.Message) -ForegroundColor Green
            return 0
        }
        Write-Host ('  {0}' -f $result.Message) -ForegroundColor Yellow
        return 1
    }

    if ($sub -eq 'update') {
        if ($offline) {
            Write-Host ''
            Write-Host '  离线模式（--offline）下不能刷新软件源，请移除 --offline 后重试。' -ForegroundColor Yellow
            Write-Host '  （本地清单在安装时会被直接读取，不需要刷新即可离线使用。）' -ForegroundColor DarkGray
            return 1
        }

        $sources = @(Get-ManifestSourceList -Context $Context)
        $targets = @()
        if ($all -or $positional.Count -eq 0) {
            $targets = @($sources)
        } else {
            foreach ($name in $positional) {
                $entry = Get-ManifestSourceByName -Context $Context -Name $name
                if (-not $entry) {
                    Write-Host ''
                    Write-Host ('  软件源不存在: {0}' -f $name) -ForegroundColor Yellow
                    Write-Host '  提示: winst manifest list 可以查看全部软件源（本地清单固定名为 local）。' -ForegroundColor DarkGray
                    return 1
                }
                $targets += $entry
            }
        }

        if ($targets.Count -eq 0) {
            Write-Host '  没有可刷新的软件源。' -ForegroundColor Yellow
            return 0
        }

        Write-Section '刷新软件源'
        $failed = 0
        $networkFailed = $false
        foreach ($source in $targets) {
            $sname = [string]$source['name']
            Write-Host ('  正在刷新 {0} …' -f $sname) -ForegroundColor Gray
            $r = Update-ManifestSource -Context $Context -Source $source
            if ($r.Success) {
                Write-Host ('    {0}: {1}' -f $sname, $r.Message) -ForegroundColor Green
                if ($r.Total -gt 0) {
                    Show-ManifestResolution -Context $Context -Name $sname -Apps $r.Apps -Preview:([bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun))
                }
            } else {
                $failed++
                if ($r.Network) { $networkFailed = $true }
                Write-Host ('    {0}: {1}' -f $sname, $r.Message) -ForegroundColor Red
            }
        }
        Write-Host ''
        Write-Host ('  汇总: 成功 {0} / 失败 {1}' -f ($targets.Count - $failed), $failed) -ForegroundColor Gray

        if ($failed -gt 0 -and $networkFailed) { return 2 }
        if ($failed -gt 0) { return 1 }
        return 0
    }

    Write-WinstUnknownSubcommand -Sub $sub -Usage 'winst manifest <add|list|update|remove>'
    return 1
}
