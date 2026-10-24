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
    若当前进程已经在执行已安装的启动器或脚本，只做更新检查——
    在目录被占用时重装只会替换正在运行进程底下的文件，没有收益。

    .OUTPUTS
        @{ Ok; Installed; Updated; Error }
#>
function Confirm-WinstSelf {
    <#
    .SYNOPSIS
        未安装则安装 winst，已安装则检查并应用更新。

    .OUTPUTS
        @{ Ok; Installed; Updated; Error }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [switch]$Quiet
    )

    $result = @{ Ok = $true; Installed = $false; Updated = $false; Error = '' }

    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun) { return $result }
    if ((Get-WinstState -Name WinstSelfChecked)) { return $result }
    $null = Set-WinstState -Name WinstSelfChecked -Value ($true)

    $installDir = Join-Path $Context.InstallRoot 'winst'
    $launcherPath = Join-Path $installDir 'winst.cmd'
    $scriptPath = Join-Path $installDir 'winst.ps1'

    # 启动器或脚本任一匹配，即认为当前进程跑的是已安装副本；
    # 用户可能直接启动其中任何一个。
    $runningInstalledCopy = $false
    $currentScript = [string](Get-WinstState -Name WinstScriptPath)

    if ($currentScript) {
        foreach ($candidate in @($launcherPath, $scriptPath)) {
            try {
                if ([IO.Path]::GetFullPath($currentScript) -ieq [IO.Path]::GetFullPath($candidate)) {
                    $runningInstalledCopy = $true
                    break
                }
            } catch {
                # 路径无法解析：保持 $runningInstalledCopy 原值。
            }
        }

        # 启动器是 .cmd，它会再启 winst.ps1；因此 $PSCommandPath 指向的是
        # 已安装的 winst.ps1，上面的循环已经覆盖这种情况。
    }

    if (-not $runningInstalledCopy -and -not (Test-Path -LiteralPath $launcherPath -PathType Leaf)) {
        $r = Install-WinstSelf -Context $Context -Quiet:$Quiet
        $result.Ok = [bool]$r.Ok
        $result.Installed = [bool]$r.Installed
        $result.Error = [string]$r.Error
        if (-not $r.Ok -and -not $Quiet) {
            Write-Host ('  winst 自动安装失败（不影响本次操作）: {0}' -f $r.Error) -ForegroundColor DarkYellow
        }
        return $result
    }

    $u = Update-WinstSelfIfOutdated -Context $Context -Quiet:$Quiet
    $result.Updated = [bool]$u.Updated
    $result.Error = [string]$u.Error
    return $result
}
