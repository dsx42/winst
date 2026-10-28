#Requires -Version 5.1

function Get-WinstDetectedVersion {
    <#
    .SYNOPSIS
        按条目的 detect 规则检测已装版本，返回最新版本与并存的旧版本。
    .DESCRIPTION
        检测出的是程序自报版本（如 java -version 的 1.8.0_504-b01）；条目若声明了 detect.versionRewrite
        ，结果按这组规则统一写法后再返回——这样「台账版本 / 界面展示 / 与软件源版本的比较」三者始终是同一套写法。

        同一个软件可能同时存在多个版本（如 .NET 运行时的旧构建 + 新装的构建）：
        - `Version` 是**最高的那个**（展示与更新判断用最新版本）；
        - `OldVersions` 是其余版本（`[ordered]@{ Version; Detail }`，从高到低），供界面提醒用户卸载旧版本；
        - `Versions` 是去重排序后的全部版本，含最新那个。
    .OUTPUTS
        @{ Ok; Found; Version; Versions; OldVersions; Method; Detail; Note }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Plan,
        [string]$InstallDir = ''
    )

    $result = Get-WinstDetectedVersionCore -Context $Context -Plan $Plan -InstallDir $InstallDir

    if (-not $result.Versions) { $result.Versions = @() }
    if (-not $result.OldVersions) { $result.OldVersions = @() }
    return $result
}
