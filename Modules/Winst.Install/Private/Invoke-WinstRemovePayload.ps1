#Requires -Version 5.1

function Invoke-WinstRemovePayload {
    <#
    .SYNOPSIS
        ① 按合并后的卸载方式分派：只移除记录 / 注册表卸载器 / 应用包 / 缓存包 / 安装目录。
    .OUTPUTS
        @{ Abort; Error }
    #>
    param([hashtable]$Context, [string]$Id, $Targets, [hashtable]$RunState, [switch]$Yes)

    switch ([string]$Targets['Method']) {
        'record-only' {
            # 仅登记且没有卸载定义：只移除登记，不动用户安装
            return @{ Abort = $false; Error = '' }
        }
        'registry' {
            return (Invoke-WinstUninstallRegistryPayload -Id $Id -Targets $Targets -RunState $RunState -Yes:$Yes)
        }
        'appx' {
            return (Invoke-WinstUninstallAppxPayload -Id $Id -Targets $Targets -RunState $RunState -Yes:$Yes)
        }
        'clean-cache' {
            try {
                Invoke-WinstFileStep -Name '删除缓存目录' -Action {
                    $cache = Remove-WinstCachedPackage -Context $Context -Id $Id -AllowMissing
                    if (-not $cache.Ok) { throw $cache.Error }
                }
            } catch {
                return @{ Abort = $true; Error = ('删除缓存目录失败，已保留安装记录：' + $_.Exception.Message) }
            }
            return @{ Abort = $false; Error = '' }
        }
        default {
            return (Invoke-WinstUninstallPortablePayload -Context $Context -Id $Id -Targets $Targets -RunState $RunState)
        }
    }
}
