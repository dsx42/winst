#Requires -Version 5.1

function Invoke-WinstUninstallPortablePayload {
    <#
    .SYNOPSIS
        portable / file（含 winst 自身）：批量删除安装目录。
    .DESCRIPTION
        两处都没有卸载定义时，回退到「安装记录里的目录」→「软件安装位置\id」。
        删除失败或路径被拒绝时中止卸载，保留安装记录与系统项，解决原因后可以重试。
    .OUTPUTS
        @{ Abort; Error }
    #>
    param([hashtable]$Context, [string]$Id, $Targets, [hashtable]$RunState)

    $dir = [string]$Targets['InstallDir']
    if (-not $dir) {
        $dir = Join-WinstPath $Context.InstallRoot $Id
    }

    # winst 安装的 portable / file 条目一律落在 <installRoot>\<id>（见 Initialize-WinstInstallContext）。
    # 台账里的 installDir 可被手工改，`C:\Users\me\Documents\Work` 这类深层目录不在
    # Test-WinstProtectedDirectory 的黑名单里，会整棵递归删掉。这里按「winst 装的一定在 installRoot 下」
    # 兜一层：越界时中止卸载，保留记录。winst 自身同样受此约束（它装在 <installRoot>\winst）。
    $managed = [string]$Targets['Managed']
    if ($dir -and $managed -eq 'winst' -and
            -not (Test-WinstPathUnderRoot -Path $dir -Root $Context.InstallRoot)) {
        return @{ Abort = $true; Error = ('安装记录里的目录不在安装位置之下，已拒绝删除并保留安装记录：{0}' -f $dir) }
    }

    try {
        if (Test-WinstFileSystemPath -Path $dir) {
            Invoke-WinstFileStep -Name '删除安装目录' -Action { Remove-WinstDirectoryTree -Path $dir }
            return @{ Abort = $false; Error = '' }
        }
    } catch {
        return @{ Abort = $true; Error = ('删除安装目录失败，已保留安装记录与系统项：{0}' -f $_.Exception.Message) }
    }
    # 安装目录已不存在：只移除安装记录与登记的系统项，不提示 winst 自身
    if (-not [bool]$Targets['IsSelf']) {
        $RunState.Notes += '安装目录已不存在，只移除安装记录与登记的系统项'
    }
    return @{ Abort = $false; Error = '' }
}
