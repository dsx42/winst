#Requires -Version 5.1

function Resolve-WinstBundleTarget {
    <#
    .SYNOPSIS
        ②③ 列出清单里的软件，并确定目标目录（未指定时交互输入，缺省落在数据根的 winst-kit）。
    .OUTPUTS
        [string] 目标目录绝对路径
    #>
    param([hashtable]$Context, [string]$TargetDir, [string]$ListPath, $Items)

    # —— ② 先列出清单里的软件（确认要打包哪些东西；状态 / 软件源 / 依赖与「查看清单」同一口径） ——
    Write-Host ''
    Write-Host ('  安装清单: {0}' -f $ListPath) -ForegroundColor Gray
    $null = Show-WinstListContent -Context $Context -Items $Items

    # —— ③ 目标目录 ——
    if (-not $TargetDir) {
        $defaultTarget = Join-WinstPath $Context.DataRoot 'winst-kit'
        Write-Host ''
        Write-Host '  安装包将复制到这个目录（可以填 U 盘上的目录，如 E:\winst-kit）。' -ForegroundColor DarkGray
        Write-Host ('  直接回车 = {0}' -f $defaultTarget) -ForegroundColor DarkGray
        $text = (Read-WinstAnswerText -Prompt '  请输入目标目录').Trim('"')
        if (-not $text) { $text = $defaultTarget }
        $TargetDir = $text
    }
    if (-not [IO.Path]::IsPathRooted($TargetDir)) {
        try { $TargetDir = (Join-WinstPath (Get-Location).Path $TargetDir) } catch { }
    }
    return $TargetDir
}
