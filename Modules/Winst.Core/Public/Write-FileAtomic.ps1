#Requires -Version 5.1

function Write-FileAtomic {
    <#
    .SYNOPSIS
        以 UTF-8 无 BOM 原子写入文本文件（临时文件 + 重命名覆盖）。
    .DESCRIPTION
        目标目录不存在时自动创建；提交失败时保留原文件并明确失败，不退化为非原子覆盖。
        写入或替换失败时同样清理临时文件——共享安装包位置（U 盘 / NAS）写失败时不留 *.tmp-*；
        临时文件删不掉（目录「可写不可删」/ 被占用）不覆盖调用方的错误，只在 --verbose 下提示路径。
        供 config.json / 远程清单缓存 / sidecar 元数据共用。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content
    )

    $Path = [IO.Path]::GetFullPath($Path)
    Assert-WinstSafeWritePath -Path $Path
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
            # 带上原始异常：调用方按类型 / HResult 识别「目录不允许写入」（ACL 拒绝），
            # 纯文本 throw 会让这条信息只剩本地化文案
            throw (New-Object System.IO.IOException (('无法创建目录 {0}：{1}' -f $dir, $_.Exception.Message), $_.Exception))
        }
    }

    $tempPath = '{0}.tmp-{1}' -f $Path, ([Guid]::NewGuid().ToString('N').Substring(0, 8))
    try {
        Assert-WinstSafeWritePath -Path $tempPath
        [IO.File]::WriteAllText($tempPath, $Content, (New-Object System.Text.UTF8Encoding($false)))
    } catch {
        # 写入临时文件失败时可能已经留下 0 字节 / 半截文件（UNC 断链、配额、ACL 拒绝）：
        # 必须清理后再抛出，否则每次失败都会在共享目录里积一个 *.tmp-*
        Remove-WinstAtomicTempFile -Path $tempPath
        throw
    }

    try {
        Assert-WinstSafeWritePath -Path $Path
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            try {
                [IO.File]::Replace($tempPath, $Path, [System.Management.Automation.Language.NullString]::Value)
            } catch {
                $cause = $_.Exception.GetBaseException()
                # 1175 保证两个文件仍在原位；同卷重命名覆盖避免 ReplaceFile 的删除步骤。
                if (($cause.HResult -band 0xffff) -ne 1175) { throw }
                Assert-WinstSafeWritePath -Path $Path
                # 重命名使用临时文件的权限，必须先保留目标文件的访问控制。
                [IO.File]::SetAccessControl($tempPath, [IO.File]::GetAccessControl($Path))
                if (-not [Winst.AtomicFile]::MoveFileEx($tempPath, $Path, 1)) {
                    $code = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
                    throw (New-Object ComponentModel.Win32Exception $code)
                }
            }
        } else {
            [IO.File]::Move($tempPath, $Path)
        }
    } catch {
        throw (New-Object IO.IOException (('无法原子写入 {0}：{1}。请检查文件占用、只读属性和目录的删除权限。' -f $Path, $_.Exception.GetBaseException().Message), $_.Exception))
    } finally {
        if ([IO.File]::Exists($tempPath)) { Remove-WinstAtomicTempFile -Path $tempPath }
    }

    # 写入后失效进程内解析缓存：否则同一进程内后续读取会拿到写入前的旧对象
    Clear-WinstJsonCache -Path $Path
}
