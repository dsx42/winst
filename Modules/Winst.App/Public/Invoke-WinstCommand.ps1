#Requires -Version 5.1

function Invoke-WinstCommand {
    <#
    .SYNOPSIS
        CLI 分发：按命令名调用对应处理函数，返回退出码。
    .DESCRIPTION
        直接调用时统一解析全局开关并保留已有 Options；入口已解析时传 -Parsed，避免重复解析。
        子命令处理函数只接收移除全局开关后的参数，按 WinstOptions 读取通用选项。
        未实现的命令会明确报错并给出帮助入口，不静默失败。
    #>
    param(
        [string]$Command = '',
        [string[]]$Arguments = @(),
        [hashtable]$Context = $null,
        [switch]$Parsed
    )

    if (-not $Parsed) {
        $parsedCommand = Read-WinstCommandLine -Tokens (@($Command) + @($Arguments)) -InitialOptions (Get-WinstState -Name WinstOptions)
        if ($parsedCommand.Error) { Write-Host ('  {0}' -f $parsedCommand.Error) -ForegroundColor Yellow; return 1 }
        $null = Set-WinstState -Name WinstOptions -Value $parsedCommand.Options
        $Command = $parsedCommand.Command
        $Arguments = @($parsedCommand.Arguments)
        if ($Context -and ($parsedCommand.Options.InstallRoot -or $parsedCommand.Options.PkgDir)) { Update-WinstContext -Context $Context }
    }

    $name = ''
    if ($null -ne $Command) { $name = ([string]$Command).Trim().ToLowerInvariant() }
    $rest = @($Arguments)
    if (($name -eq 'repair' -or $name -in @('--version','-v','version')) -and $rest.Count -gt 0) {
        Write-Host ('  {0} 不接受额外参数。' -f $name) -ForegroundColor Yellow
        return 1
    }
    if (($name -in @('--help','-h','help','?','-?')) -and
        ($rest.Count -gt 1 -or @($rest | Where-Object { $_.StartsWith('-') }).Count -gt 0)) {
        Write-Host '  help 只接受一个命令名。' -ForegroundColor Yellow
        return 1
    }

    # 命令之前的 -v / --version / -h / --help 也在此处理（此时 Command 为空）
    if (-not $name -and $rest.Count -gt 0) {
        $first = ([string]$rest[0]).Trim()
        if ($first -ieq '--version' -or $first -ieq '-v') {
            Write-Host (Get-WinstProductVersion)
            return 0
        }
        if ($first -ieq '--help' -or $first -ieq '-h' -or $first -ieq '-?') {
            return (Show-WinstHelp)
        }
    }

    if ($name -eq '--version' -or $name -eq '-v' -or $name -eq 'version') {
        Write-Host (Get-WinstProductVersion)
        return 0
    }
    if ($name -eq '--help' -or $name -eq '-h' -or $name -eq 'help' -or $name -eq '?' -or $name -eq '-?') {
        $topic = ''
        if ($rest.Count -gt 0) { $topic = [string]$rest[0] }
        return (Show-WinstHelp -Command $topic)
    }

    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Offline) {
        Write-Host '  严格离线模式：本次不会联网（只用已有的解析结果与缓存；软件源要先刷新过一次才可见）。' -ForegroundColor DarkGray
    }

    $ctx = $Context
    if (-not $ctx) { $ctx = New-WinstContext -Options (Get-WinstState -Name WinstOptions) }

    switch ($name) {
        'search'    { return (Invoke-WinstSearchCommand -Context $ctx -Arguments $rest) }
        'info'      { return (Invoke-WinstInfoCommand -Context $ctx -Arguments $rest) }
        'install'   { return (Invoke-WinstInstallCommand -Context $ctx -Arguments $rest) }
        'download'  { return (Invoke-WinstInstallCommand -Context $ctx -Arguments $rest -DownloadOnly) }
        'list'      { return (Invoke-WinstListCommand -Context $ctx -Arguments $rest) }
        'update'    { return (Invoke-WinstUpdateCommand -Context $ctx -Arguments $rest) }
        'uninstall' { return (Invoke-WinstUninstallCommand -Context $ctx -Arguments $rest) }
        'clean'     { return (Invoke-WinstCleanCommand -Context $ctx -Arguments $rest) }
        'repair'    { return (Invoke-Repair -Context $ctx) }
        'manifest'  { return (Invoke-ManifestCommand -Context $ctx -Arguments $rest) }
        'bundle'    { return (Invoke-WinstBundleCommand -Context $ctx -Arguments $rest) }
        'config'    { return (Invoke-WinstConfigCommand -Context $ctx -Arguments $rest) }
        default     {
            # 命令位置为空（如 `winst --bogus`）时，报出真正认不出的那个 token
            $shown = $name
            if (-not $shown -and $rest.Count -gt 0) { $shown = [string]$rest[0] }
            if (-not $shown) { $shown = '(未指定)' }
            Write-Host ''
            Write-Host ('  未知的命令: {0}' -f $shown) -ForegroundColor Yellow
            Write-Host '  用 winst help 查看全部命令。' -ForegroundColor Gray
            return 1
        }
    }
}
