#Requires -Version 5.1

function Get-WinstRowBestPlanEntry {
    <#
    .SYNOPSIS
        取一行里「版本最高的可用来源」那一条（含它的 Plan），供只下载 / 打包流程直接使用。
    .DESCRIPTION
        版本号取自主包文件信息的条目（versionFromPackage）本来就没有源侧版本号，「最高版本」那条无从谈起
        ——这类条目退回**第一个可用的来源**：它的 Plan 里照样有地址与定义，取到包后即可从
        包内文件信息读出真实版本，因此下载 / 打包含义不变。
        比较逻辑完全复用 Get-WinstRowBestSourceEntry，不先取投影再反查，少扫一遍 Sources。
    .OUTPUTS
        @{ Source; Version; Ok; Error; Plan } 或 $null
    #>
    param($Row)

    if (-not $Row) { return $null }
    $best = Get-WinstRowBestSourceEntry -Row $Row
    if ($best) { return $best }
    if (Test-WinstRowVersionFromPackage -Row $Row) {
        foreach ($candidate in @($Row['Sources'])) {
            if ($candidate['Ok'] -and $candidate['Plan']) { return $candidate }
        }
    }
    return $null
}
