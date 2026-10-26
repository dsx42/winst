#Requires -Version 5.1

function Get-WinstProductNameKey {
    <#
    .SYNOPSIS
        把系统安装记录里的显示名归一成「同一个产品」的比较键（抹掉带点的版本号）。
    .DESCRIPTION
        同一个产品升级后，DisplayName 通常只差版本号：
        `Microsoft Windows Desktop Runtime - 10.0.13 (x64)` 与
        `Microsoft Windows Desktop Runtime - 10.0.14 (x64)` 抹掉版本后相等，说明是同一产品的新旧两版。

        只抹「带点的版本号」（`10.0.13` / `10.0.13.50000` / `1.8.0_504`），不动单独的年份与产品代号：
        `Microsoft Visual C++ 2019 Redistributable (x64)` 与 `... 2022 ...` 抹完仍是两个不同的键——
        它们是**两个可以并存的产品**，不能把其中一个报成「旧版本」让用户卸掉。
        同理 x64 / x86 的包也保留在新旧比较之外。
    .OUTPUTS
        [string] 归一后的产品键
    #>
    param([string]$DisplayName)

    $text = ([string]$DisplayName).Trim()
    if (-not $text) { return '' }
    $text = [regex]::Replace($text, '\d+(?:\.\d+)+', '#')
    # `Runtime - 10.0.13` 与 `Runtime 10.0.13` 只差分隔符，归一成同一种写法
    $text = [regex]::Replace($text, '\s*-\s*#', ' #')
    $text = [regex]::Replace($text, '\s+', ' ')
    return $text.Trim()
}
