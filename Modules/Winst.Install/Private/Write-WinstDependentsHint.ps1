#Requires -Version 5.1

function Write-WinstDependentsHint {
    <#
    .SYNOPSIS
        依赖提示：列出依赖它的已安装软件（直接 + 间接），仅提示、不拦截卸载。
    #>
    param([hashtable]$Context, [string]$Id)

    $dependents = Get-WinstDependents -Context $Context -Id $Id
    if (-not $dependents.Ok -or @($dependents.Items).Count -eq 0) { return }

    Write-Host ''
    Write-Host '  提示: 下列已安装的软件依赖它，卸载后它们可能无法正常使用：' -ForegroundColor Yellow
    foreach ($one in @($dependents.Items)) {
        $level = [int]$one['Level']
        $kindText = '直接依赖'
        if ($level -gt 1) {
            $viaName = [string]$one['ViaName']
            if (-not $viaName) { $viaName = [string]$one['Via'] }
            $kindText = ('间接依赖，经 {0}' -f $viaName)
        }
        Write-Host ('    - {0}（{1}）' -f [string]$one['Name'], $kindText) -ForegroundColor Gray
    }
    Write-Host '  这仅是提示，不影响卸载；如需保留可改用其它软件。' -ForegroundColor DarkGray
}
