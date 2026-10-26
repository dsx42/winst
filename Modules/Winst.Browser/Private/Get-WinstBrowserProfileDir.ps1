#Requires -Version 5.1

function Get-WinstBrowserProfileDir {
    <#
    .SYNOPSIS
        返回无头浏览器抓页面用的进程级临时 profile 目录（没有就创建）。
    .DESCRIPTION
        同一进程内复用同一个 profile（省掉每次新建用户目录的首次运行开销）；目录不存在（首次 / 被重建）
        时新建，并顺手清掉异常退出残留的旧 profile（只动超过 24 小时的，避免碰到并行进程正在用的目录）。
    #>
    if ((Get-WinstState -Name WinstBrowserProfileDir) -and (Test-Path -LiteralPath (Get-WinstState -Name WinstBrowserProfileDir) -PathType Container)) {
        return (Get-WinstState -Name WinstBrowserProfileDir)
    }
    try {
        foreach ($oldProfile in @(Get-ChildItem -Path ([IO.Path]::GetTempPath()) -Directory -ErrorAction SilentlyContinue |
                Where-Object { ($_.Name -like 'winst-browser-*' -or $_.Name -like 'winst-cdp-*') -and $_.CreationTime -lt (Get-Date).AddHours(-24) })) {
            Clear-WinstInstallDir -Dir $oldProfile.FullName
        }
    } catch { }
    $dir = Join-WinstPath ([IO.Path]::GetTempPath()) ('winst-browser-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
    $null = New-Item -ItemType Directory -Path $dir -Force -ErrorAction SilentlyContinue
    $null = Set-WinstState -Name WinstBrowserProfileDir -Value ($dir)
    return $dir
}
