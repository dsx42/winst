#Requires -Version 5.1

function Clear-WinstInstallDir {
    <#
    .SYNOPSIS
        清理安装目录（清理模式）：无 keep 时整目录删除，有 keep 时逐项删除并保留命中内容。
    .DESCRIPTION
        `-AllowedRoot`：要求目录必须位于该根目录之下（缓存包删除这类「路径完全由 id 拼出」的场景必须传，
        id 越界时直接拒绝）。安装目录可以合法地落在 Program Files 等安装根之外，因此那里不传该参数，
        改用 Test-WinstProtectedDirectory 的前缀黑名单拦住系统目录。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [string[]]$Keep = @(),
        [string]$AllowedRoot = ''
    )

    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return }

    # $Dir 可能来自注册表 / 脏台账 / 带 .. 的 id：盘根、系统目录、用户目录一律拒绝删除，
    # 避免一条脏记录把整盘或用户目录递归清空。这里不抛异常（多数调用点没有 try/catch），只提示并跳过。
    if (Test-WinstProtectedDirectory -Path $Dir) {
        Write-Host ('    提示: 拒绝清理可疑目录 {0}（不像软件安装目录），请手动确认。' -f $Dir) -ForegroundColor Yellow
        return
    }
    if (Test-WinstReparsePoint -Path $Dir) {
        Write-Host ('    提示: 拒绝清理重解析点（junction / 符号链接）{0}，请手动确认。' -f $Dir) -ForegroundColor Yellow
        return
    }
    # `$Dir` 自身可能不是重解析点，但父级可以是（base\junction\victim）。此时枚举 Dir 已经进入
    # junction 目标，逐项安全删除也会删到目标目录；因此从卷根到 Dir 的整条现有路径都要检查。
    $dirFull = ''
    $pathRoot = ''
    try {
        $dirFull = [IO.Path]::GetFullPath($Dir)
        $pathRoot = [IO.Path]::GetPathRoot($dirFull)
    } catch {
        $dirFull = ''
        $pathRoot = ''
    }
    if (-not $dirFull -or -not $pathRoot -or (Test-WinstPathHasReparsePoint -Path $dirFull -Root $pathRoot)) {
        Write-Host ('    提示: 拒绝清理经过重解析点的目录 {0}，请手动确认。' -f $Dir) -ForegroundColor Yellow
        return
    }
    if ($AllowedRoot -and -not (Test-WinstPathUnderRoot -Path $Dir -Root $AllowedRoot)) {
        Write-Host ('    提示: 拒绝清理安装包位置之外的目录 {0}（应位于 {1} 之下）。' -f $Dir, $AllowedRoot) -ForegroundColor Yellow
        return
    }

    foreach ($item in @(Get-ChildItem -LiteralPath $Dir -Force -ErrorAction SilentlyContinue)) {
        Remove-WinstItemWithKeep -Item $item -Base $Dir -Keep $Keep
    }
    # 无 keep 时应删除根目录本身；只做非递归删除，绝不让文件系统 API 跟随嵌套重解析点。
    if (@($Keep).Count -eq 0) {
        $remain = @(Get-ChildItem -LiteralPath $Dir -Force -ErrorAction SilentlyContinue)
        if ($remain.Count -eq 0) {
            try { [IO.Directory]::Delete($Dir, $false) } catch { }
        }
    }
}
