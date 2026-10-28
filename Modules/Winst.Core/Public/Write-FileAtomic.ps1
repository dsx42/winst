#Requires -Version 5.1

function Write-FileAtomic {
    <#
    .SYNOPSIS
        以 UTF-8 无 BOM 原子写入文本文件（临时文件 + 重命名覆盖）。
    .DESCRIPTION
        目标目录不存在时自动创建（含多级父目录）；Replace 不被目标卷支持时退化为直接覆盖写入。
        供 config.json / 远程清单缓存 / sidecar 元数据共用。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content
    )

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
        # 目录不存在有两种原因：真的没有（建它），或整个盘当前不可见——
        # 别的登录会话里映射的网络盘在提权进程里访问会抛
        # DriveNotFoundException「找不到驱动器。名为 "Z" 的驱动器不存在」。
        # 网络共享只支持 UNC 路径，因此这里直接引导用户改用 UNC，而不是原样抛出驱动器错误。
        try {
            $null = New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop
        } catch [System.Management.Automation.DriveNotFoundException] {
            throw ('目标盘当前不可用（{0}）：网络共享请改用 UNC 路径（\\服务器\共享名\目录），不要用映射盘符。' -f $dir)
        } catch [System.IO.IOException] {
            throw ('无法创建目录 {0}：{1}' -f $dir, $_.Exception.Message)
        }
    }

    $tempPath = '{0}.tmp-{1}' -f $Path, ([Guid]::NewGuid().ToString('N').Substring(0, 8))
    [IO.File]::WriteAllText($tempPath, $Content, (New-Object System.Text.UTF8Encoding($false)))

    try {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            [IO.File]::Replace($tempPath, $Path, $null)
        } else {
            [IO.File]::Move($tempPath, $Path)
        }
    } catch {
        try {
            # 退化路径（如目标卷不支持 Replace）：直接覆盖写入
            Copy-Item -LiteralPath $tempPath -Destination $Path -Force -ErrorAction Stop
        } finally {
            # 成功 / 失败都清掉临时文件：共享安装包位置（U 盘 / NAS）写失败时不留 *.tmp-*
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }

    # 写入后失效进程内解析缓存：否则同一进程内后续读取会拿到写入前的旧对象
    Clear-WinstJsonCache -Path $Path
}
