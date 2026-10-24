#Requires -Version 5.1

function Invoke-WinstBundleCommand {
    <#
    .SYNOPSIS
        CLI `winst bundle`：list / edit / install / pack。
    .OUTPUTS
        [int] 退出码
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string[]]$Arguments = @()
    )

    $sub = ''
    $file = ''
    $dir = ''
    $skipExisting = $false
    $skipMissing = $false

    foreach ($token in @($Arguments)) {
        $text = [string]$token
        if ($text -ieq '--skip-existing') { $skipExisting = $true; continue }
        if ($text -ieq '--skip-missing') { $skipMissing = $true; continue }
        if ($text.StartsWith('-')) {
            Write-Host ''
            Write-Host ('  bundle 不支持参数: {0}' -f $text) -ForegroundColor Yellow
            return 1
        }
        if (-not $sub) { $sub = $text.ToLowerInvariant(); continue }
        if ($sub -eq 'pack') {
            if (-not $file) { $file = $text } elseif (-not $dir) { $dir = $text }
        } elseif (-not $file) {
            $file = $text
        }
    }

    switch ($sub) {
        ''        { Show-BundleCliHelp; return 1 }
        'help'    { Show-BundleCliHelp; return 0 }
        'list'    { return (Invoke-WinstListShowCli -Context $Context -Path $file) }
        'edit'    {
            # 编辑是交互流程（选清单 → 挑选软件 → 保存 / 放弃），走菜单同一实现
            Invoke-WinstListEditFlow -Context $Context -Path $file
            return 0
        }
        'install' { return (Invoke-WinstBundleInstallCli -Context $Context -Path $file -SkipExisting:$skipExisting) }
        'pack'    { return (Invoke-WinstBundlePackCli -Context $Context -ListText $file -DirText $dir -SkipMissing:$skipMissing) }
        default   {
            Write-WinstUnknownSubcommand -Sub $sub -HelpFunction 'Show-BundleCliHelp'
            return 1
        }
    }
}
