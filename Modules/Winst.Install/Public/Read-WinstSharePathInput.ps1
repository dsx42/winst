#Requires -Version 5.1

function Read-WinstSharePathInput {
    <#
    .SYNOPSIS
        读取并校验一个「安装包位置 / 安装位置」路径：UNC 路径 + 可选的账号密码。
    .DESCRIPTION
        网络共享只接受 UNC 路径，不接受映射盘符：映射按登录会话生效，winst 以管理员身份
        运行时往往看不到非提权会话里映射的盘符。

        交互顺序（账号、密码都可以留空跳过）：

            1. 路径  —— 只填 UNC（`\\服务器\共享名\目录`），路径里不带账号密码
            2. 账号  —— 直接回车表示不需要认证
            3. 密码  —— 直接回车表示不需要认证

        账号填了、密码留空视为放弃认证（只填账号无法认证），会重新询问。
        认证失败时保留已输入的路径、只重新询问账号密码，不必重头再输一遍。

        认证交给 Windows 凭据管理器：`Set-WinstUncCredential` 先用 net use 验证，
        成功才写凭据库。**winst 不保存账号密码**，返回值里只有干净的 UNC 路径。

        密码用 `Read-Host -AsSecureString` 读取（不回显）。该参数在输入被重定向时会挂起，
        因此非交互环境下明确报错，不做静默降级。

        本地路径（含本地盘符）原样返回，由调用方按本地路径规则继续处理。
    .PARAMETER Prompt
        路径输入提示语。
    .OUTPUTS
        @{ Ok; Cancelled; Path; Error }

        Cancelled = $true 表示用户直接回车 / 输入空值放弃。
    #>
    param([string]$Prompt = '  请输入 UNC 路径（直接回车取消）')

    $result = @{ Ok = $false; Cancelled = $false; Path = ''; Error = '' }

    # ---------------------------------------------------------------- ① 路径
    $raw = $null
    try { $raw = Read-Host $Prompt } catch { $result.Cancelled = $true; return $result }
    if ($null -eq $raw -or -not ([string]$raw).Trim()) {
        $result.Cancelled = $true
        return $result
    }
    $inputText = ([string]$raw).Trim().Trim('"').Trim()
    if (-not $inputText) {
        $result.Cancelled = $true
        return $result
    }

    $parsed = Resolve-WinstUncInput -Value $inputText
    if (-not $parsed.Ok) {
        $result.Error = [string]$parsed.Error
        return $result
    }
    if ([bool]$parsed.IsLocalDrive) {
        $result.Ok = $true
        $result.Path = [string]$parsed.Path
        return $result
    }

    $value = [string]$parsed.Path
    if (-not $value.StartsWith('\\')) {
        $result.Ok = $true
        $result.Path = $value
        return $result
    }

    $serverParts = @($value.Substring(2) -split '\\' | Where-Object { $_ -ne '' })
    $server = ''
    if ($serverParts.Count -gt 0) { $server = [string]$serverParts[0] }

    # -------------------------------------------------- ②③ 账号 / 密码（可重试）
    while ($true) {
        $user = ''
        try { $user = Read-Host '  账号（直接回车＝不需要认证）' } catch { $result.Cancelled = $true; return $result }
        $user = ([string]$user).Trim()
        if ($user -and $user -match '[\x00-\x1F]') {
            $result.Error = '账号含有控制字符'
            return $result
        }

        $password = ''
        if ($user) {
            if (Test-WinstInputRedirected) {
                $result.Error = '当前输入被重定向，无法安全地输入密码。请在交互式终端里重新运行 winst（设置 → 安装包位置）。'
                return $result
            }
            $secure = $null
            try { $secure = Read-Host ('  {0} 的密码（直接回车＝重新输入账号）' -f $user) -AsSecureString } catch {
                $result.Cancelled = $true
                return $result
            }
            if ($null -ne $secure -and $secure.Length -gt 0) {
                $bstr = [IntPtr]::Zero
                try {
                    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
                    $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
                } finally {
                    if ($bstr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
                }
            }
            $secure = $null

            if (-not $password) {
                # 只填账号不填密码无法认证：回到账号输入，不静默跳过
                Write-Host '  未输入密码，无法认证；请重新输入账号（直接回车＝不需要认证）。' -ForegroundColor DarkYellow
                Write-Host ''
                continue
            }
        }

        # 账号密码都留空：沿用已保存的凭据 / 匿名访问，只验证一次可达性
        if (-not $user) {
            if (Test-WinstUncReachable -Path $value) {
                $result.Ok = $true
                $result.Path = $value
                return $result
            }
            $result.Error = ('无法访问 {0}。若该共享需要认证，请重新输入并填写账号与密码。' -f $value)
            return $result
        }

        Write-Host ''
        Write-Host ('  正在用账号 {0} 认证网络共享 …' -f $user) -ForegroundColor Gray
        $auth = Set-WinstUncCredential -Server $server -User $user -Password $password -Path $value
        $password = ''
        if ($auth.Ok) {
            Write-Host '  认证成功，凭据已交给系统凭据管理器保存。' -ForegroundColor Green
            $result.Ok = $true
            $result.Path = $value
            return $result
        }

        Write-Host ('  认证失败：{0}' -f [string]$auth.Error) -ForegroundColor Red
        Write-Host '  请重新输入账号与密码（路径已保留，直接回车放弃）。' -ForegroundColor DarkGray
        Write-Host ''
    }
}
