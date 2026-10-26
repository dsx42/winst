#Requires -Version 5.1

function Get-WinstEngineExe {
    <#
    .SYNOPSIS
        定位引擎可执行文件：优先台账记录的安装目录 + 主程序，其次按约定路径 installRoot\<id>\ 探测。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$MainExe = ''
    )

    if (-not $MainExe) { $MainExe = Get-WinstEngineMainExe -Id $Id }
    if (-not $MainExe) { return '' }

    # 进程内缓存：解压 / 下载 / 引擎自检会反复定位同一个引擎，每次定位都要读一遍 state.json
    if ($null -eq (Get-WinstState -Name WinstEnginePathCache)) {
        $null = Set-WinstState -Name WinstEnginePathCache -Value (New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase))
    }
    $cacheKey = ('{0}|{1}' -f $Context.InstallRoot, $Id)
    if ((Get-WinstState -Name WinstEnginePathCache).ContainsKey($cacheKey)) { return [string](Get-WinstState -Name WinstEnginePathCache)[$cacheKey] }

    $found = ''
    $state = (Read-WinstState -InstallRoot $Context.InstallRoot).State
    $entry = Get-WinstInstalledApp -State $state -Id $Id
    if ($entry) {
        $dir = Get-EntryString -Entry $entry -Key 'installDir'
        if ($dir) {
            $candidate = Join-WinstPath $dir $MainExe
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { $found = $candidate }
        }
    }
    if (-not $found) {
        $probe = Join-WinstPath (Join-WinstPath $Context.InstallRoot $Id) $MainExe
        if (Test-Path -LiteralPath $probe -PathType Leaf) { $found = $probe }
    }
    # 未找到时不缓存：本次会话里引擎可能刚被安装，下一次定位必须能读到新装的路径
    if ($found) { (Get-WinstState -Name WinstEnginePathCache)[$cacheKey] = $found }
    return $found
}
