#Requires -Version 5.1

function Install-WinstFilePayload {
    <#
    .SYNOPSIS
        ② file：把主包复制到安装目录（临时文件 + 原子替换，失败时目标文件保持原样）。
    .DESCRIPTION
        落位用「临时文件 + 原子替换」而不是直接覆盖：更新 winst 自身时目标就是正在运行的 winst.ps1
        （PowerShell 启动后不持有文件句柄，可以替换），但直接覆盖是「先截断再写」，中途失败会留下半截脚本；
        先写临时文件再 Replace/Move，失败时目标文件保持原样。
    .OUTPUTS
        @{ Ok; Error }
    #>
    param([string]$InstallDir, [string]$PrimaryPath)

    $fileName = Split-Path -Leaf $PrimaryPath
    if (-not $fileName) { return @{ Ok = $false; Error = '安装包文件名不可用，无法落位单文件条目' } }
    if (-not (Test-Path -LiteralPath $InstallDir -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $InstallDir -Force -ErrorAction SilentlyContinue
    }
    $fileTarget = Join-Path $InstallDir $fileName
    $fileTemp = Join-Path $InstallDir ('.winst-new-' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.tmp')
    try {
        Copy-Item -LiteralPath $PrimaryPath -Destination $fileTemp -Force -ErrorAction Stop
        if (Test-Path -LiteralPath $fileTarget -PathType Leaf) {
            try {
                [IO.File]::Replace($fileTemp, $fileTarget, $null)
            } catch {
                # 目标卷不支持 Replace / 目标被别的进程占用：退化为直接覆盖（与 Write-FileAtomic 同一策略）
                Copy-Item -LiteralPath $fileTemp -Destination $fileTarget -Force -ErrorAction Stop
                Remove-Item -LiteralPath $fileTemp -Force -ErrorAction SilentlyContinue
            }
        } else {
            Move-Item -LiteralPath $fileTemp -Destination $fileTarget -Force -ErrorAction Stop
        }
    } catch {
        Remove-Item -LiteralPath $fileTemp -Force -ErrorAction SilentlyContinue
        return @{ Ok = $false; Error = ('复制程序文件失败：{0}' -f $_.Exception.Message) }
    }
    return @{ Ok = $true; Error = '' }
}
