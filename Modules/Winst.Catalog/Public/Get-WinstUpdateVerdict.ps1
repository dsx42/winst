#Requires -Version 5.1

function Get-WinstUpdateVerdict {
    <#
    .SYNOPSIS
        版本结论判定：已装软件 / 已下载包 / 软件列表 / 清单预览四处共用。
    .DESCRIPTION
        四个视图构造函数共用「remoteFresh → 比较版本 → update / latest / newer」的判定矩阵
        （同一句提示文案出现 5 次），其中 New-WinstListItem 漏了 versionFromPackage 的 remoteFresh 分支，
        同一条目在「软件列表」与「已装软件」里会给出不同结论。统一到这里。
    .OUTPUTS
        @{ State; Hint; HasUpdate }
    #>
    param(
        [string]$BestVersion,
        [string]$CurrentVersion,
        [bool]$VersionFromPackage = $false,
        [string]$RemoteFresh = '',
        $Row = $null,
        [switch]$ForPackage,
        [string]$MissingCurrentState = 'unknown'
    )

    $freshChanged = '↑ 远端有新包（HEAD 检测），建议重新下载'
    $freshUnknown = '↑ 无法判断远端是否有新包（HEAD 检测未得出结论）'

    if ($ForPackage) {
        # 安装包结论：三条新鲜度分支都要求「缓存里有版本」
        if ($VersionFromPackage -and $BestVersion -and $CurrentVersion -and $RemoteFresh -ieq 'changed') {
            return @{ State = 'update'; Hint = $freshChanged; HasUpdate = $true }
        }
        if ($VersionFromPackage -and $BestVersion -and $CurrentVersion -and $RemoteFresh -ieq 'unchanged') {
            return @{ State = 'latest'; Hint = ''; HasUpdate = $false }
        }
        if ($VersionFromPackage -and $BestVersion -and $CurrentVersion) {
            return @{ State = 'update'; Hint = $freshUnknown; HasUpdate = $true }
        }
        if (-not $BestVersion) { return @{ State = 'unknown'; Hint = ''; HasUpdate = $false } }
        if (-not $CurrentVersion) { return @{ State = 'cache-unknown'; Hint = ''; HasUpdate = $false } }
        $cmpPackage = Compare-WinstVersion -A $BestVersion -B $CurrentVersion
        if ($cmpPackage -gt 0) { return @{ State = 'update'; Hint = ('↑ 可更新到 {0}' -f $BestVersion); HasUpdate = $true } }
        if ($cmpPackage -eq 0) { return @{ State = 'latest'; Hint = ''; HasUpdate = $false } }
        return @{ State = 'newer'; Hint = ''; HasUpdate = $false }
    }

    # 已装软件结论：unchanged 不特判，直接比较（远端无新包时缓存版本即远端当前版本）
    if ($VersionFromPackage -and $BestVersion -and $RemoteFresh -ieq 'changed') {
        return @{ State = 'update'; Hint = $freshChanged; HasUpdate = $true }
    }
    if ($VersionFromPackage -and $BestVersion -and $RemoteFresh -ine 'unchanged') {
        return @{ State = 'update'; Hint = $freshUnknown; HasUpdate = $true }
    }
    if (-not $BestVersion) { return @{ State = 'unknown'; Hint = ''; HasUpdate = $false } }
    if (-not $CurrentVersion) { return @{ State = $MissingCurrentState; Hint = ''; HasUpdate = $false } }

    $cmp = Compare-WinstVersion -A $BestVersion -B $CurrentVersion
    if ($cmp -gt 0) {
        $hint = ('↑ 可更新到 {0}' -f $BestVersion)
        if ($null -ne $Row) { $hint = Get-WinstUpgradeHint -Row $Row -InstalledVersion $CurrentVersion -WithSource }
        return @{ State = 'update'; Hint = $hint; HasUpdate = $true }
    }
    if ($cmp -eq 0) { return @{ State = 'latest'; Hint = ''; HasUpdate = $false } }
    return @{ State = 'newer'; Hint = ''; HasUpdate = $false }
}
