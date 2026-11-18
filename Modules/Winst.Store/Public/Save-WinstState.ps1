#Requires -Version 5.1

function Save-WinstState {
    <#
    .SYNOPSIS
        原子写入安装台账（<安装根目录>\state.json；UTF-8 无 BOM；schemaVersion 2）。
    .DESCRIPTION
        写完立即用**刚写入的内容**刷新台账读缓存，而不是简单清空：
        清空会让紧随其后的读重新解析一遍（写入后几乎总要再读一次），
        直接刷新则让「写完再读」保持缓存命中。外部改动仍由文件戳兜底。

        失效范围按「谁真的依赖台账」划定：注册表卸载项、Appx 包、环境变量、引擎路径
        都以台账 / 系统安装状态为依据，必须重读；而**进程快照**只反映「当前有哪些进程」
        （另有 3 秒 TTL 自管），**本地清单文件列表**只反映脚本目录与 pkgDir 下的文件，
        两者都与台账内容无关，不随台账变化失效——否则写一次台账就要重新枚举一次
        全部进程（实测冷启动约 1.1 秒），把「写台账」变成整条流程里最贵的一步。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$InstallRoot,
        [Parameter(Mandatory = $true)][hashtable]$State
    )

    $installed = $State['Installed']
    if ($null -eq $installed) { $installed = (New-WinstOrdinalDictionary) }

    Assert-WinstDistinctIds -Ids @($installed.Keys)
    $normalized = New-WinstOrdinalDictionary
    foreach ($id in @($installed.Keys)) { $normalized[$id] = ConvertTo-WinstInstalledEntry -Entry $installed[$id] }
    Write-WinstInstalledState -InstallRoot $InstallRoot -Installed $installed -Normalized $normalized
}
