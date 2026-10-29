#Requires -Version 5.1

function Remove-WinstAtomicTempFile {
    <#
    .SYNOPSIS
        删除原子写入的临时文件；删不掉时重试一次，仍失败则在 --verbose 下给出路径。
    .DESCRIPTION
        共享安装包位置（U 盘 / NAS）常见「可写不可删」与瞬时断链：删除失败本身是环境问题，
        但这里不能再抛出、覆盖调用方正在处理的原始错误，因此只做一次重试 + verbose 提示。
        临时文件留在共享目录里不会影响功能（读取只认精确路径），但每次刷新都会再积一个。
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    for ($attempt = 1; $attempt -le 2; $attempt++) {
        try { Remove-Item -LiteralPath $Path -Force -ErrorAction Stop } catch { }
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
        # 服务端杀软 / 备份扫描可能短暂占用刚写完的临时文件：等一下再试一次
        if ($attempt -lt 2) { Start-Sleep -Milliseconds 50 }
    }

    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
        Write-Host ('  [verbose] 临时文件未能删除（目录可能不允许删除，或文件被其它进程占用）：{0}' -f $Path) -ForegroundColor DarkGray
    }
}
