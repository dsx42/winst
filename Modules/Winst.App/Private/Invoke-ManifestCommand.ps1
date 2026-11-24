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
        [string[]]$Arguments
    )

    $tokens = @()
    if ($Arguments) { $tokens = @($Arguments) }

    if ($tokens.Count -eq 0) {
        Show-ManifestCliHelp
        return 1
    }

    $sub = ([string]$tokens[0]).ToLowerInvariant()
    $rest = @()
    if ($tokens.Count -gt 1) { $rest = @($tokens[1..($tokens.Count - 1)]) }

    $all = $rest -contains '--all'
    $positional = @($rest | Where-Object { $_ -ne '--all' })

    if (@('add','list','update','remove') -notcontains $sub -or
        @($positional | Where-Object { ([string]$_).StartsWith('-') }).Count -gt 0 -or
        ($all -and ($sub -ne 'update' -or $positional.Count -gt 0)) -or
        ($sub -eq 'list' -and $positional.Count -gt 0) -or
        ($sub -in @('add','remove') -and $positional.Count -ne 1)) {
        Write-Host '  manifest 子命令或参数不合法。' -ForegroundColor Yellow
        return 1
    }

    Ensure-OfficialManifest -Context $Context

    if ($sub -eq 'list') {
        Invoke-ManifestList -Context $Context
        return 0
    }

    if ($sub -eq 'add') {
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
        $dryRun = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun)
        $result = Remove-RemoteManifest -Context $Context -Name $positional[0] -DryRun:$dryRun
        Write-Host ''
        if ($result.Success) {
            Write-Host ('  {0}' -f $result.Message) -ForegroundColor Green
            return 0
        }
        Write-Host ('  {0}' -f $result.Message) -ForegroundColor Yellow
        return 1
    }

    $options = Get-WinstState -Name WinstOptions
    if ($options -and $options.Offline) {
        Write-Host ''
        Write-Host '  离线模式（--offline）下不能刷新软件源，请移除 --offline 后重试。' -ForegroundColor Yellow
        Write-Host '  离线安装需要已有的解析结果和安装包。本地清单也须先移除 --offline 并刷新一次。' -ForegroundColor DarkGray
        return 1
    }

    $sources = @(Get-ManifestSourceList -Context $Context)
    $targets = @()
    if ($positional.Count -eq 0) {
        $targets = @($sources)
    } else {
        foreach ($name in $positional) {
            $entry = $sources | Where-Object { $_['name'] -ieq $name } | Select-Object -First 1
            if (-not $entry) {
                Write-Host ''
                Write-Host ('  软件源不存在: {0}' -f $name) -ForegroundColor Yellow
                Write-Host '  提示: winst manifest list 可以查看全部软件源（本地清单固定名为 local）。' -ForegroundColor DarkGray
                return 1
            }
            $targets += $entry
        }
    }

    $refresh = Invoke-ManifestRefreshAll -Context $Context -Sources $targets
    if ($refresh.Network) { return 2 }
    if ($refresh.Failed -gt 0) { return 1 }
    return 0
}
