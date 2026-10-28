#Requires -Version 5.1

function Invoke-PathSettingItem {
    <#
    .SYNOPSIS
        路径类设置项（软件安装位置 / 安装包位置）：校验 → 建目录 → 写入 config.json → 刷新横幅。
    .DESCRIPTION
        值按用户输入原样保存（含 %VAR% 形式），读取时展开；相对路径以数据根目录为基准。

        切换**软件安装位置**（installRoot）时会把旧位置下已有的软件目录列出来提示用户：
        新位置只对此后的安装生效，已装软件留在原处继续可用，用户需要知道旧位置里还有哪些软件。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context,
        [Parameter(Mandatory = $true)]
        [string]$Key,
        [Parameter(Mandatory = $true)]
        [string]$DisplayName,
        [Parameter(Mandatory = $true)]
        [string]$CurrentDisplay,
        [string]$Hint = ''
    )

    Write-Section $DisplayName
    Write-Host ('  当前值: {0}  {1}' -f $CurrentDisplay, (Get-ConfigTag -Context $Context -Key $Key)) -ForegroundColor Gray
    if ($Hint) {
        # 提示可能有多行（如网络盘的 UNC 说明）：逐行输出，缩进对齐「说明:」
        $hintLines = @(([string]$Hint) -split "`r?`n")
        Write-Host ('  说明:   {0}' -f $hintLines[0]) -ForegroundColor DarkGray
        if ($hintLines.Count -gt 1) {
            for ($i = 1; $i -lt $hintLines.Count; $i++) {
                Write-Host ('          {0}' -f $hintLines[$i]) -ForegroundColor DarkGray
            }
        }
    }
    Write-Host '  路径支持 %VAR% 环境变量（读取时展开）；相对路径以数据目录为基准。' -ForegroundColor DarkGray
    Write-Host ''

    # 读输入：网络共享只收 UNC；账号、密码随后单独询问（可留空表示不需要认证）。
    # 具体编排在 Winst.Install 的 Read-WinstSharePathInput 里，本层只负责展示与落盘。
    $entered = Read-WinstSharePathInput -Prompt '  请输入新路径（UNC 路径直接回车取消）'
    if ([bool]$entered.Cancelled) {
        Write-Host '  已取消。' -ForegroundColor DarkGray
        return
    }
    if (-not [bool]$entered.Ok) {
        Write-Host ''
        Write-Host ('  路径无效：{0}' -f [string]$entered.Error) -ForegroundColor Yellow
        return
    }

    $value = [string]$entered.Path
    $resolved = Expand-WinstPath -Path $value -Base $Context.DataRoot

    $errorMessage = ''
    if (-not $value) {
        $errorMessage = '路径不能为空'
    } elseif ($resolved -match '%[^%]+%') {
        $errorMessage = '路径中的环境变量未被系统识别，请检查拼写'
    } elseif ($value -match '[*?]') {
        $errorMessage = '路径不能包含通配符 * 或 ?'
    } elseif ($value.IndexOfAny([IO.Path]::GetInvalidPathChars()) -ge 0) {
        $errorMessage = '路径包含非法字符'
    } elseif ($resolved -match '^[A-Za-z]:[\\/]?$') {
        $errorMessage = '不能直接使用盘符根目录，请指定一个具体目录'
    } elseif (Test-Path -LiteralPath $resolved -PathType Leaf) {
        $errorMessage = '目标已存在且是一个文件，请指定一个目录'
    }

    if ($errorMessage) {
        Write-Host ''
        Write-Host ('  路径无效：{0}' -f $errorMessage) -ForegroundColor Yellow
        return
    }

    # 目录不存在则创建（含多级父目录），顺带暴露无写权限等问题
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        try {
            $null = New-Item -ItemType Directory -Path $resolved -Force -ErrorAction Stop
            Write-Host ('  已创建目录: {0}' -f $resolved) -ForegroundColor DarkGray
        } catch {
            Write-Host ''
            Write-Host ('  无法创建目录: {0}' -f $resolved) -ForegroundColor Red
            Write-Host ('  原因: {0}' -f $_.Exception.Message) -ForegroundColor DarkGray
            Write-Host '  已取消。' -ForegroundColor DarkGray
            return
        }
    }

    # 切换软件安装位置：只提示旧位置下已有哪些软件，不搬、不改
    if ($Key -eq 'installRoot') {
        $oldInstallRoot = [string]$Context.InstallRoot
        if ($oldInstallRoot -and $oldInstallRoot.TrimEnd('\', '/') -ine $resolved.TrimEnd('\', '/')) {
            $existing = @(Get-WinstInstalledDirList -InstallRoot $oldInstallRoot)
            if ($existing.Count -gt 0) {
                Write-Host ''
                Write-Host ('  旧位置下现有 {0} 个软件目录：' -f $existing.Count) -ForegroundColor Gray
                Write-Host ('    {0}' -f $oldInstallRoot) -ForegroundColor DarkGray
                foreach ($one in $existing) {
                    Write-Host ('    - {0}' -f [string]$one) -ForegroundColor Gray
                }
                Write-Host ''
                Write-Host '  换位置只对此后的安装生效：上面这些软件留在原处继续可用。' -ForegroundColor DarkGray
                Write-Host '  （安装记录跟着安装位置存放，新位置暂时是空的；进入「已装软件」会自动扫描登记。）' -ForegroundColor DarkGray
            }
        }
    }

    $configPath = Join-WinstPath $Context.DataRoot 'config.json'
    $Context.Config[$Key] = $value
    try {
        Save-WinstConfig -DataRoot $Context.DataRoot -Config $Context.Config
    } catch {
        Write-Host ''
        Write-Host ('  写入配置失败: {0}' -f $configPath) -ForegroundColor Red
        Write-Host ('  原因: {0}' -f $_.Exception.Message) -ForegroundColor DarkGray
        Write-Host '  已取消。' -ForegroundColor DarkGray
        return
    }

    Update-WinstContext -Context $Context

    $cliOverride = ''
    # 选项对象可能是 hashtable 或 PSCustomObject：用键存在性读取，避免 StrictMode 下访问不存在的成员抛异常
    $options = Get-WinstState -Name WinstOptions
    if ($Key -eq 'installRoot' -and (Get-EntryString -Entry $options -Key 'InstallRoot')) { $cliOverride = '--install-root' }
    if ($Key -eq 'pkgDir' -and (Get-EntryString -Entry $options -Key 'PkgDir')) { $cliOverride = '--pkg-dir' }

    Write-Host ''
    Write-Host ('  已保存到: {0}' -f $configPath) -ForegroundColor Green
    Write-Host ('  配置项:   {0} = {1}' -f $Key, $value) -ForegroundColor Gray
    Write-Host ('  实际生效位置: {0}' -f (Expand-WinstPath -Path $value -Base $Context.DataRoot)) -ForegroundColor Gray
    if ($cliOverride) {
        Write-Host ('  注意: 本次运行使用了命令行参数 {0}，其优先级高于配置；重新运行 winst 后以配置为准。' -f $cliOverride) -ForegroundColor Yellow
    }
    Write-Host '  提示: 已打开的终端需重开（或重新运行 winst）后 PATH / 环境变量才完全生效。' -ForegroundColor DarkGray
}
