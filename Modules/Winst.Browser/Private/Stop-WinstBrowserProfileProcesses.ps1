#Requires -Version 5.1

function Stop-WinstBrowserProfileProcesses {
    <#
    .SYNOPSIS
        结束仍在使用某个 winst 专用 profile 目录的 Edge 进程（整棵进程树）。
    .DESCRIPTION
        为什么要按 profile 目录匹配，而不是按 Start-Process 拿到的 PID：`-PassThru` 返回的不一定是最终的
        浏览器主进程——Edge 在新建 profile / 自升级时会再拉起一个主进程、最初那个立刻退出，按 PID 杀就会
        漏掉真正在跑的那个，残留实例一直占着 profile（本机实测一次刷新能留下好几个）。

        残留实例还有一个直接后果：同一个 profile 被占用时，再起 `--dump-dom` 不会输出任何东西——新进程
        只是把命令行转交给在跑的实例，自己立刻以 0 退出（stderr 里是「Multiple targets are not supported
        in headless mode」）。抓页面因此表现为「浏览器没有返回页面内容」，重试也一样，除非先把占用者清掉。

        只按 winst 自己的临时目录名（`winst-browser-*` / `winst-cdp-*`）下手：用户正在用的浏览器不可能
        指向这些目录，传进来别的路径直接不动。
    .OUTPUTS
        [int] 结束的进程数
    #>
    param([string]$ProfileDir)

    if (-not $ProfileDir) { return 0 }
    $leaf = Split-Path -Leaf $ProfileDir
    if ($leaf -notlike 'winst-browser-*' -and $leaf -notlike 'winst-cdp-*') { return 0 }

    $killed = 0
    try {
        $targets = @(Get-CimInstance -ClassName Win32_Process -Filter "Name='msedge.exe'" -ErrorAction Stop |
                Where-Object { $_.CommandLine -and $_.CommandLine.IndexOf($ProfileDir, [StringComparison]::OrdinalIgnoreCase) -ge 0 })
    } catch {
        # 查不到进程列表（WMI 不可用等）不是致命问题：调用方仍会用新目录兜底
        return 0
    }

    foreach ($target in $targets) {
        try {
            $null = & taskkill.exe /PID ([int]$target.ProcessId) /T /F 2>&1
            $killed++
        } catch { }
    }
    # 进程结束与文件句柄释放之间有间隙：紧接着启动浏览器时 profile 仍可能被判为「在用」
    if ($killed -gt 0) { Start-Sleep -Milliseconds 600 }
    return $killed
}
