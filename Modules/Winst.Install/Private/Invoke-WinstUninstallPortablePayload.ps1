#Requires -Version 5.1

function Invoke-WinstUninstallPortablePayload {
    <#
    .SYNOPSIS
        portable / file（含 winst 自身）：整目录删除安装目录，并检查残留。
    .DESCRIPTION
        两处都没有卸载定义时，回退到「安装记录里的目录」→「软件安装位置\id」。
        删除失败、路径被拒绝或仍有残留时中止卸载，保留安装记录与系统项，解决原因后可以重试。
    .OUTPUTS
        @{ Abort; Error }
    #>
    param([hashtable]$Context, [string]$Id, $Targets, [hashtable]$RunState, [switch]$Quiet)

    $dir = [string]$Targets['InstallDir']
    if (-not $dir) {
        $candidate = Join-WinstPath $Context.InstallRoot $Id
        if (Test-Path -LiteralPath $candidate -PathType Container) { $dir = $candidate }
    }

    # winst 安装的 portable / file 条目一律落在 <installRoot>\<id>（见 Initialize-WinstInstallContext）。
    # 台账里的 installDir 可被手工改，`C:\Users\me\Documents\Work` 这类深层目录不在
    # Test-WinstProtectedDirectory 的黑名单里，会整棵递归删掉。这里按「winst 装的一定在 installRoot 下」
    # 兜一层：越界时中止卸载，保留记录。winst 自身同样受此约束（它装在 <installRoot>\winst）。
    $managed = [string]$Targets['Managed']
    if (-not $managed) { $managed = 'winst' }
    if ($dir -and $managed -eq 'winst' -and
            -not (Test-WinstPathUnderRoot -Path $dir -Root $Context.InstallRoot)) {
        return @{ Abort = $true; Error = ('安装记录里的目录不在安装位置之下，已拒绝删除并保留安装记录：{0}' -f $dir) }
    }

    if ($dir -and (Test-Path -LiteralPath $dir -PathType Container)) {
        if (-not $Quiet) { Write-Host ('    正在删除 {0} …' -f $dir) -ForegroundColor Gray }
        try {
            Clear-WinstInstallDir -Dir $dir
        } catch {
            return @{ Abort = $true; Error = ('删除安装目录失败，已保留安装记录：{0}' -f $_.Exception.Message) }
        }
        if (Test-Path -LiteralPath $dir -PathType Container) {
            $RunState.Leftovers += $dir
            return @{ Abort = $true; Error = ('安装目录未删除，已保留安装记录与系统项；请关闭占用程序或检查权限后重试：{0}' -f $dir) }
        }
        return @{ Abort = $false; Error = '' }
    }
    # 安装目录已不存在：只移除安装记录与登记的系统项，不提示 winst 自身
    if (-not [bool]$Targets['IsSelf']) {
        $RunState.Notes += '安装目录已不存在，只移除安装记录与登记的系统项'
    }
    return @{ Abort = $false; Error = '' }
}
