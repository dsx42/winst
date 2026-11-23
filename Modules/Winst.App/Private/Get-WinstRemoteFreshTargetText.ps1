#Requires -Version 5.1

function Get-WinstRemoteFreshTargetText {
    <#
    .SYNOPSIS
        把「远端新鲜度」结论转成展示用的目标版本文案（安装确认和下载列表共用）。
    .DESCRIPTION
        versionFromPackage 条目在解析阶段按清单声明比对主包，结论存在解析锁的 remoteFresh 字段：
          changed   → 远端有新包，版本要取包后才知道
          unchanged → 远端无新包，缓存里那份就是软件源当前这份，目标版本直接用它
          unknown   → 主包比较没有得出结论，如实说明
    .OUTPUTS
        [string] 目标版本文案
    #>
    param(
        [string]$Fresh,
        [string]$FallbackVersion = ''
    )

    if ($fresh -ieq 'changed') { return '远端文件已变化，取包后确认版本' }
    if ($fresh -ieq 'unchanged') {
        if ($FallbackVersion) {
            return ('{0}（远端无新包）' -f $FallbackVersion)
        }
        return '远端无新包（缓存里那份版本未知），取包后确认版本'
    }
    return '取包后确认版本（无法判断远端文件是否变化）'
}
