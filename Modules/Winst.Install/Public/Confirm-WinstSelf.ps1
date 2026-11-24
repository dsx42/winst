#Requires -Version 5.1
<#
    Confirm-WinstSelf.ps1  (Winst.Install / Public)

    确保 winst 自身已安装且为最新版本。

    检测目标
    --------
    winst 以目录形式安装，因此「已安装」意味着启动器存在：

        <installRoot>\winst\winst.cmd

    检测必须针对 winst.cmd 而不是 winst.ps1：清单里的 mainExe 是 winst.cmd，
    快捷方式指向它，只有 winst.ps1 的目录属于装坏了。

    当前进程跑的就是已安装副本时
    ----------------------------
    若当前进程已经在执行已安装的脚本，只做更新检查——
    在目录被占用时重装只会替换正在运行进程底下的文件，没有收益。
#>
function Confirm-WinstSelf {
    <#
    .SYNOPSIS
        未安装则安装 winst，已安装则检查并应用更新。
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context
    )

    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun) { return }
    if ((Get-WinstState -Name WinstInstallingAppIds) -ccontains 'winst') { return }
    if ((Get-WinstState -Name WinstSelfChecked)) { return }
    $null = Set-WinstState -Name WinstSelfChecked -Value ($true)

    $installDir = Join-WinstPath $Context.InstallRoot 'winst'
    $launcherPath = Join-WinstPath $installDir 'winst.cmd'
    $scriptPath = Join-WinstPath $installDir 'winst.ps1'

    $currentScript = [string](Get-WinstState -Name WinstScriptPath)
    try {
        $runningInstalledCopy = [IO.Path]::GetFullPath($currentScript) -ieq [IO.Path]::GetFullPath($scriptPath)
    } catch {
        $runningInstalledCopy = $false
    }

    if (-not $runningInstalledCopy -and -not (Test-Path -LiteralPath $launcherPath -PathType Leaf)) {
        $r = Install-WinstSelf -Context $Context
        if (-not $r.Ok) {
            Write-Host ('  winst 自动安装失败（不影响本次操作）: {0}' -f $r.Error) -ForegroundColor DarkYellow
        }
        return
    }

    Update-WinstSelfIfOutdated -Context $Context
}
