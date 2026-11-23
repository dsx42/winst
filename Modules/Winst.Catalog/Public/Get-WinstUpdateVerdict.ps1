#Requires -Version 5.1

function Get-WinstUpdateVerdict {
    <#
    .SYNOPSIS
        已装软件、已下载包、软件列表和清单预览共用的版本结论。
    .DESCRIPTION
        先应用 package 来源的远端新鲜度，再比较可用版本；返回统一状态与提示。
    .OUTPUTS
        @{ State; Hint; HasUpdate }
    #>
    param(
        [string]$BestVersion,
        [string]$CurrentVersion,
        [bool]$VersionFromPackage = $false,
        [string]$RemoteFresh = '',
        [switch]$ForPackage,
        [string]$BestSource = ''
    )

    if ($CurrentVersion -ieq 'unknown') { $CurrentVersion = '' }
    if ($BestVersion -ieq 'unknown') { $BestVersion = '' }

    if ($VersionFromPackage) {
        if ($RemoteFresh -ieq 'changed') {
            if ($ForPackage) { return @{ State = 'update'; Hint = '远端文件已变化，可以更新缓存包'; HasUpdate = $true } }
            return @{ State = 'unknown'; Hint = '远端文件已变化，软件版本待确认'; HasUpdate = $false }
        }
        if ($RemoteFresh -ine 'unchanged') {
            return @{ State = 'unknown'; Hint = '无法确认远端文件是否变化，软件版本待确认'; HasUpdate = $false }
        }
        if (-not $BestVersion) { return @{ State = 'unknown'; Hint = '无法读取缓存安装包版本'; HasUpdate = $false } }
        if (-not $ForPackage -and -not $CurrentVersion) { return @{ State = 'unknown'; Hint = '无法读取本机版本'; HasUpdate = $false } }
        if ($ForPackage -and $CurrentVersion) { return @{ State = 'latest'; Hint = ''; HasUpdate = $false } }
    }
    if (-not $ForPackage -and -not $CurrentVersion) {
        return @{ State = 'update'; Hint = '↑ 本机版本未知，可按软件源定义更新'; HasUpdate = $true }
    }

    if (-not $BestVersion) { return @{ State = 'unknown'; Hint = ''; HasUpdate = $false } }
    if (-not $CurrentVersion) { return @{ State = 'cache-unknown'; Hint = ''; HasUpdate = $false } }

    $cmp = Compare-WinstVersion -A $BestVersion -B $CurrentVersion
    if ($cmp -gt 0) {
        $hint = ('↑ 可更新到 {0}' -f $BestVersion)
        if ($BestSource) { $hint += ('（来自 {0}）' -f $BestSource) }
        return @{ State = 'update'; Hint = $hint; HasUpdate = $true }
    }
    if ($cmp -eq 0) { return @{ State = 'latest'; Hint = ''; HasUpdate = $false } }
    return @{ State = 'newer'; Hint = ''; HasUpdate = $false }
}
