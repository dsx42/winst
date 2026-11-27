#Requires -Version 5.1

function Save-WinstState {
    <#
    .SYNOPSIS
        原子写入安装台账（<安装根目录>\state.json；UTF-8 无 BOM；schemaVersion 2）。
    .DESCRIPTION
        写完立即用**刚写入的内容**刷新台账读缓存，而不是简单清空：
        清空会让紧随其后的读重新解析一遍（写入后几乎总要再读一次），
        直接刷新则让「写完再读」保持缓存命中。外部改动仍由文件戳兜底。

        台账写入后清空注册表卸载项、Appx 包、环境变量和引擎路径的缓存。
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
