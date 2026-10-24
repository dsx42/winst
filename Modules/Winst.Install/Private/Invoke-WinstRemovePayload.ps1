#Requires -Version 5.1

function Invoke-WinstRemovePayload {
    <#
    .SYNOPSIS
        ① 按合并后的卸载方式分派：只移除记录 / 注册表卸载器 / 应用包 / 缓存包 / 安装目录。
    .OUTPUTS
        @{ Abort; Error }
    #>
    param([hashtable]$Context, [string]$Id, $Targets, $Ledger, [hashtable]$RunState, [switch]$Yes, [switch]$Quiet)

    switch ([string]$Targets['Method']) {
        'record-only' {
            # 仅登记且没有卸载定义：只移除登记，不动用户安装
            return @{ Abort = $false; Error = '' }
        }
        'registry' {
            return (Invoke-WinstUninstallRegistryPayload -Context $Context -Id $Id -Targets $Targets -Ledger $Ledger -RunState $RunState -Yes:$Yes -Quiet:$Quiet)
        }
        'appx' {
            return (Invoke-WinstUninstallAppxPayload -Context $Context -Id $Id -Targets $Targets -RunState $RunState -Yes:$Yes -Quiet:$Quiet)
        }
        'clean-cache' {
            Invoke-WinstUninstallCachePayload -Context $Context -Id $Id -Quiet:$Quiet
            return @{ Abort = $false; Error = '' }
        }
        default {
            Invoke-WinstUninstallPortablePayload -Context $Context -Id $Id -Targets $Targets -RunState $RunState -Quiet:$Quiet
            return @{ Abort = $false; Error = '' }
        }
    }
}
