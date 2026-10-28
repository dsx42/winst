#Requires -Version 5.1

function Resolve-WinstUncInput {
    <#
    .SYNOPSIS
        校验一个 UNC 路径（`\\服务器\共享名\目录`），返回规范化后的形式。
    .DESCRIPTION
        网络共享只接受 UNC 路径，不接受映射盘符（`Z:\...`）：映射是按登录会话生效的，
        winst 以管理员身份运行时往往看不到非提权会话里映射的盘符。

        本函数**只接收合法 UNC 路径**，账号密码由调用方另外询问（见 Read-WinstSharePathInput）：

            \\服务器\共享名\目录

        路径里不允许再嵌账号密码（`\\账号:密码@服务器\共享名`），那种写法会原样出现在
        命令行历史 / 屏幕回显里，不能接受。

        本函数只做格式校验，**不碰凭据存储、不发网络请求**。
    .OUTPUTS
        @{ Ok; Path; Error; IsMappedDrive; IsLocalDrive }

        Ok = $false 时 Error 说明原因；IsMappedDrive = $true 表示输入是网络映射盘符 / 不可用盘符
        （调用方据此给「改写 UNC」的专门提示）；IsLocalDrive = $true 表示是本地盘路径，
        调用方应按本地路径继续处理。
    #>
    param([string]$Value)

    $result = @{
        Ok            = $false
        Path          = ''
        Error         = ''
        IsMappedDrive = $false
        IsLocalDrive  = $false
    }

    $text = ([string]$Value).Trim()
    if (-not $text) { $result.Error = '路径不能为空'; return $result }
    # 用户常从资源管理器复制到带引号的路径
    $text = $text.Trim('"').Trim()
    if (-not $text) { $result.Error = '路径不能为空'; return $result }

    # 盘符：本地盘（固定 / 可移动 / 光驱）是合法路径，交回调用方按本地路径处理；
    # 网络映射盘则明确拒绝——映射只在当前登录会话可见，winst 以管理员身份运行时可能访问不到。
    if ($text -match '^([A-Za-z]):') {
        $letter = $Matches[1].ToUpperInvariant()
        $driveType = 'NoRootDirectory'
        try { $driveType = (New-Object IO.DriveInfo($letter)).DriveType.ToString() } catch { $driveType = 'NoRootDirectory' }

        if ($driveType -eq 'Fixed' -or $driveType -eq 'Removable' -or $driveType -eq 'CDRom' -or $driveType -eq 'Ram') {
            $result.IsLocalDrive = $true
            $result.Ok = $true
            $result.Path = $text
            return $result
        }
        if ($driveType -eq 'Network') {
            $result.IsMappedDrive = $true
            $result.Error = ('不支持映射盘符（{0}）：映射只在当前登录会话可见，winst 以管理员身份运行时可能访问不到。请改用 UNC 路径：\\服务器\共享名\目录' -f $text.Substring(0, 2))
            return $result
        }
        # 盘符在当前会话不存在（本地盘被拔掉 / 别的会话映射的网络盘，这里不做任何推断）
        $result.IsMappedDrive = $true
        $result.Error = ('盘符 {0} 当前不可访问。若它是网络共享，请改用 UNC 路径：\\服务器\共享名\目录' -f $text.Substring(0, 2))
        return $result
    }

    if (-not $text.StartsWith('\\')) {
        $result.Error = '网络共享路径必须以 \\ 开头（UNC 格式：\\服务器\共享名\目录）'
        return $result
    }

    # 校验 UNC 结构：\\服务器\共享名[\子路径...]
    $parts = @($text.Substring(2) -split '\\' | Where-Object { $_ -ne '' })
    if ($parts.Count -lt 1) {
        $result.Error = 'UNC 路径缺少服务器名（\\服务器\共享名\目录）'
        return $result
    }
    $server = $parts[0]
    # 服务器名里的引号会让后续 cmdkey 参数拼接失效；控制字符 / 空白 / 冒号 / @ 同样不合法
    if ($server -match '[\x00-\x1F\s"''<>|]' -or $server.Contains(':') -or $server.Contains('@')) {
        $result.Error = '服务器名不合法（UNC 格式：\\服务器\共享名\目录；账号密码请在其后单独输入）'
        return $result
    }
    if ($parts.Count -lt 2) {
        $result.Error = 'UNC 路径缺少共享名（\\服务器\共享名\目录）'
        return $result
    }
    foreach ($segment in $parts) {
        if ($segment -eq '.' -or $segment -eq '..') {
            $result.Error = ('UNC 路径不能包含 . 或 ..：{0}' -f $text)
            return $result
        }
    }

    $trimmed = $text.TrimEnd('\')
    try { $trimmed = [IO.Path]::GetFullPath($trimmed) } catch { }
    # GetFullPath 会把 \\server\share 归一成 \\server\share\，去掉尾部分隔符（共享根保留）
    $trimmed = $trimmed.TrimEnd('\')
    if (-not $trimmed.StartsWith('\\')) {
        $result.Error = ('不是合法的 UNC 路径：{0}' -f $text)
        return $result
    }

    $result.Ok = $true
    $result.Path = $trimmed
    return $result
}
