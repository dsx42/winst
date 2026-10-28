#Requires -Version 5.1

function Set-WinstUncCredential {
    <#
    .SYNOPSIS
        验证账号密码确实能访问该共享，然后交给 Windows 凭据管理器（cmdkey）保存。
    .DESCRIPTION
        网络共享需要认证时，winst 不自己保存账号密码，而是交给系统的凭据管理器：
        登记后由 Windows 在访问该服务器时自动使用，winst 与其它程序都能受益。

        **先验证、后写入**：用 `net use` 以显式凭据连一次该服务器的 IPC$，成功才写凭据库。
        这样错误密码不会进入凭据管理器，也不会动到该服务器已有的可用凭据
        （`cmdkey /add` 本身会覆盖同名目标，因此不能先删后加——失败时会连累
        同一服务器上其它共享的既有凭据）。

        **不能只看 cmdkey 的退出码**：实测 cmdkey 对不存在的服务器同样返回 0
        并打印「成功保存凭据」，所以它不能用来判断认证是否成功。

        密码以 `/pass:<密码>` 传给 cmdkey（cmdkey 没有从标准输入读密码的写法），
        因此可能出现在该进程的命令行里；进程以隐藏窗口启动、输出被重定向，
        报错信息在返回前会把 `/pass:` 后面的内容遮蔽掉。
    .OUTPUTS
        @{ Ok; Error }
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Server,
        [Parameter(Mandatory = $true)][string]$User,
        [Parameter(Mandatory = $true)][string]$Password,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $result = @{ Ok = $false; Error = '' }

    $cmdkey = ''
    try { $cmdkey = Join-WinstPath $env:SystemRoot 'System32\cmdkey.exe' } catch { $cmdkey = '' }
    if (-not $cmdkey -or -not (Test-Path -LiteralPath $cmdkey -PathType Leaf)) {
        $result.Error = '找不到系统命令 cmdkey.exe，无法保存网络共享凭据'
        return $result
    }
    $netExe = ''
    try { $netExe = Join-WinstPath $env:SystemRoot 'System32\net.exe' } catch { $netExe = '' }

    # —— ① 先验证：用显式凭据连 IPC$，不写凭据库 —
    if ($netExe -and (Test-Path -LiteralPath $netExe -PathType Leaf)) {
        $probeArgs = 'use {0} /user:{1} {2}' -f `
            (Format-WinstCommandArgument -Value ('\\' + $Server + '\IPC$')), `
            (Format-WinstCommandArgument -Value $User), `
            (Format-WinstCommandArgument -Value $Password)
        $probe = Invoke-WinstCapturedCommand -FilePath $netExe -Arguments $probeArgs -TimeoutMs 30000
        if (-not $probe.Ok -or $probe.ExitCode -ne 0) {
            # 成功时会把会话留着；失败时不会有会话可清
            $result.Error = ('凭据验证失败：{0}。请检查账号 / 密码，以及该账号是否有此共享的访问权限' -f $Path)
            return $result
        }
        # 验证成功，拆掉这条临时会话（凭据随后由 cmdkey 提供，避免留下隐性映射）
        try {
            $null = Invoke-WinstCapturedCommand -FilePath $netExe `
                -Arguments ('use {0} /delete' -f (Format-WinstCommandArgument -Value ('\\' + $Server + '\IPC$'))) -TimeoutMs 15000
        } catch { }
    }

    # —— ② 写入凭据库 —
    # 不先 /delete：cmdkey /add 对同名目标本身就是覆盖；先删后加时 /add 一旦失败，
    # 该服务器原有可用的凭据已被删掉，同一服务器上其它共享会一起失去访问能力

    $addArgs = '/add:{0} /user:{1} /pass:{2}' -f `
        (Format-WinstCommandArgument -Value $Server), `
        (Format-WinstCommandArgument -Value $User), `
        (Format-WinstCommandArgument -Value $Password)
    $add = Invoke-WinstCapturedCommand -FilePath $cmdkey -Arguments $addArgs -TimeoutMs 15000
    if (-not $add.Ok) {
        # 捕获结果里的 Error 可能含完整命令行（超时分支会拼 $Arguments），
        # 而这里带着 /pass:<密码>：报给用户前先把密码遮蔽掉
        $safeError = ([string]$add.Error) -replace '(/pass:)\S+', '$1***'
        $result.Error = ('保存凭据失败：{0}' -f $safeError)
        return $result
    }

    # —— ③ 复核：凭据写入后确实能访问（避免凭据管理器拒绝等情况） —
    if (-not (Test-WinstUncReachable -Path $Path)) {
        $result.Error = ('凭据已保存，但仍无法访问 {0}；请检查该账号对此目录的权限' -f $Path)
        return $result
    }

    $result.Ok = $true
    return $result
}
