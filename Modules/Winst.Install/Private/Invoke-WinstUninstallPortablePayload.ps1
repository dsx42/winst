#Requires -Version 5.1

function Invoke-WinstUninstallPortablePayload {
    <#
    .SYNOPSIS
        portable / exe（含 winst 自身）：整目录删除安装目录，并检查残留。
    .DESCRIPTION
        两处都没有卸载定义时，回退到「安装记录里的目录」→「软件安装位置\id」。
        目录删除后仍有残留时，记入 RunState.Leftovers 供界面提示用户手动处理。
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
    # 兜一层：越界只报告、不删，交给用户手动处理。winst 自身同样受此约束（它装在 <installRoot>\winst）。
    $managed = [string]$Targets['Managed']
    if (-not $managed) { $managed = 'winst' }
    if ($dir -and $managed -eq 'winst' -and
            -not (Test-WinstPathUnderRoot -Path $dir -Root $Context.InstallRoot)) {
        $RunState.Notes += ('安装记录里的目录不在安装位置之下，已拒绝删除（请手动确认）：{0}' -f $dir)
        return
    }

    if ($dir -and (Test-Path -LiteralPath $dir -PathType Container)) {
        if (-not $Quiet) { Write-Host ('    正在删除 {0} …' -f $dir) -ForegroundColor Gray }
        try {
            Clear-WinstInstallDir -Dir $dir
        } catch {
            $RunState.Notes += ('删除安装目录失败：{0}' -f $_.Exception.Message)
        }
        if (Test-Path -LiteralPath $dir -PathType Container) {
            $remain = @(Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue)
            # 兜底删除同样要过保护判定：$dir 来自台账（可被手工改），且递归删除会跟随 junction
            if ($remain.Count -eq 0 -and -not (Test-WinstProtectedDirectory -Path $dir) -and -not (Test-WinstReparsePoint -Path $dir)) {
                try { [IO.Directory]::Delete($dir, $false) } catch { }
            }
            if (Test-Path -LiteralPath $dir -PathType Container) {
                $RunState.Leftovers += $dir
                $RunState.Notes += ('安装目录仍有残留（可能有程序正在运行），请关闭后手动删除: {0}' -f $dir)
            }
        }
        return
    }
    # 安装目录已不存在：只移除安装记录与登记的系统项，不提示 winst 自身
    if (-not [bool]$Targets['IsSelf']) {
        $RunState.Notes += '安装目录已不存在，只移除安装记录与登记的系统项'
    }
}
