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
        $Row = $null,
        [switch]$ForPackage,
        [string]$MissingCurrentState = 'unknown',
        [string]$BestSource = ''
    )

    $freshChanged = '↑ 远端有新包（文件比较），建议重新下载'
    $freshUnknown = '↑ 无法判断远端是否有新包（文件比较未得出结论）'
    if ($CurrentVersion -ieq 'unknown') { $CurrentVersion = '' }
    if ($BestVersion -ieq 'unknown') { $BestVersion = '' }

    if (-not $ForPackage -and -not $CurrentVersion) {
        $usable = [bool]$BestVersion
        if ($null -ne $Row) {
            $usable = $false
            foreach ($source in @(Get-EntryArray -Entry $Row -Key 'Sources')) {
                if ((Get-EntryBool -Entry $source -Key 'Ok') -and (Get-EntryValue -Entry $source -Key 'Plan' -Default $null)) { $usable = $true; break }
            }
        }
        if ($usable) { return @{ State = 'update'; Hint = '↑ 本机版本未知，可按软件源定义更新'; HasUpdate = $true } }
        return @{ State = $MissingCurrentState; Hint = '本机版本未知'; HasUpdate = $false }
    }

    if ($VersionFromPackage -and $BestVersion -and $CurrentVersion) {
        if ($RemoteFresh -ieq 'changed') { return @{ State = 'update'; Hint = $freshChanged; HasUpdate = $true } }
        if ($RemoteFresh -ine 'unchanged') { return @{ State = 'update'; Hint = $freshUnknown; HasUpdate = $true } }
        if ($ForPackage) { return @{ State = 'latest'; Hint = ''; HasUpdate = $false } }
    }
    if (-not $BestVersion) { return @{ State = 'unknown'; Hint = ''; HasUpdate = $false } }
    if (-not $CurrentVersion) { return @{ State = 'cache-unknown'; Hint = ''; HasUpdate = $false } }

    $cmp = Compare-WinstVersion -A $BestVersion -B $CurrentVersion
    if ($cmp -gt 0) {
        $hint = ('↑ 可更新到 {0}' -f $BestVersion)
        if (-not $ForPackage -and -not $VersionFromPackage) {
            if ($BestSource) { $hint += ('（来自 {0}）' -f $BestSource) }
            elseif ($null -ne $Row -and -not $PSBoundParameters.ContainsKey('BestSource')) {
                $hint = Get-WinstUpgradeHint -Row $Row -InstalledVersion $CurrentVersion -WithSource
            }
        }
        return @{ State = 'update'; Hint = $hint; HasUpdate = $true }
    }
    if ($cmp -eq 0) { return @{ State = 'latest'; Hint = ''; HasUpdate = $false } }
    return @{ State = 'newer'; Hint = ''; HasUpdate = $false }
}
