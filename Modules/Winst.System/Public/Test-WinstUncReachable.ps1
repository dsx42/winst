#Requires -Version 5.1

function Test-WinstUncReachable {
    <#
    .SYNOPSIS
        判断一个 UNC 路径当前是否真的可访问（用于验证网络共享及其凭据）。
    .DESCRIPTION
        只做一次目录枚举：`Test-Path` 对网络路径在认证失败时同样只返回 $false，
        但也有个别情况（如共享根本不存在）会让它抛异常，这里统一收敛成布尔值。

        不做重试、不猜原因：调用方按 $false 报「连不上」即可。
    .OUTPUTS
        [bool]
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not $Path) { return $false }
    if (-not $Path.StartsWith('\\')) { return $false }

    try {
        # 先看目标本身（共享根或子目录）是否可直接枚举
        if (Test-Path -LiteralPath $Path -PathType Container -ErrorAction Stop) {
            $null = [IO.Directory]::GetFileSystemEntries($Path)
            return $true
        }
    } catch {
        return $false
    }

    # 子目录可能尚未创建：退一步确认共享根可访问
    $parts = @($Path.Substring(2) -split '\\' | Where-Object { $_ -ne '' })
    if ($parts.Count -lt 2) { return $false }
    $shareRoot = '\\' + $parts[0] + '\' + $parts[1]
    try {
        if (-not (Test-Path -LiteralPath $shareRoot -PathType Container -ErrorAction Stop)) { return $false }
        $null = [IO.Directory]::GetFileSystemEntries($shareRoot)
        return $true
    } catch {
        return $false
    }
}
