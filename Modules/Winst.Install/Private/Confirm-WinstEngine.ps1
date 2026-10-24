#Requires -Version 5.1

function Confirm-WinstEngine {
    <#
    .SYNOPSIS
        确保指定引擎可用：已有则按进程级策略检查更新，缺失则引导安装。
    .OUTPUTS
        @{ Ok; Exe; Error; Installed }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        [switch]$Quiet
    )

    $exe = Get-WinstEngineExe -Context $Context -Id $Id
    if ($exe) {
        $null = Update-WinstEngineIfOutdated -Context $Context -Id $Id -Quiet:$Quiet
        $exe = Get-WinstEngineExe -Context $Context -Id $Id
        if ($exe) { return @{ Ok = $true; Exe = $exe; Error = ''; Installed = $false } }
        return @{ Ok = $false; Exe = ''; Error = ('{0} 更新后没有找到主程序，请重新执行；如持续出现请到「软件列表」里重装它。' -f $Id); Installed = $false }
    }

    $r = Install-WinstEngine -Context $Context -Id $Id -Quiet:$Quiet
    return @{ Ok = $r.Ok; Exe = $r.Exe; Error = $r.Error; Installed = $r.Installed }
}
