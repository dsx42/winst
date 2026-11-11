#Requires -Version 5.1

function Confirm-WinstEngine {
    <#
    .SYNOPSIS
        确保指定引擎可用：当前安装目标只复用已有程序，其余按进程级策略更新或引导安装。
    .OUTPUTS
        @{ Ok; Exe; Error; Installed }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        [switch]$Quiet
    )

    $exe = Get-WinstEngineExe -Context $Context -Id $Id
    if ((Get-WinstState -Name WinstInstallingAppIds) -ccontains $Id) {
        if ($exe) { return @{ Ok = $true; Exe = $exe; Error = ''; Installed = $false } }
        return @{ Ok = $false; Exe = ''; Error = ('{0} 正在安装，但主程序尚不可用，无法供当前依赖使用。请先单独安装此引擎。' -f $Id); Installed = $false }
    }
    if ($exe) {
        $null = Update-WinstEngineIfOutdated -Context $Context -Id $Id -Quiet:$Quiet
        $exe = Get-WinstEngineExe -Context $Context -Id $Id
        if ($exe) { return @{ Ok = $true; Exe = $exe; Error = ''; Installed = $false } }
        return @{ Ok = $false; Exe = ''; Error = ('{0} 更新后没有找到主程序，请重新执行；如持续出现请到「软件列表」里重装它。' -f $Id); Installed = $false }
    }

    $r = Install-WinstEngine -Context $Context -Id $Id -Quiet:$Quiet
    return @{ Ok = $r.Ok; Exe = $r.Exe; Error = $r.Error; Installed = $r.Installed }
}
