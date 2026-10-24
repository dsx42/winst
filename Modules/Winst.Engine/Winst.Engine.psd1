@{
    RootModule           = 'Winst.Engine.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'c7d1af7c-00bb-4ad6-8028-45a91dbf6ba0'
    Author               = 'winst'
    CompanyName          = 'winst'
    Copyright            = '(c) winst'
    Description          = '下载与解压引擎（低层）：FluxDown CLI 调用、7-Zip 解压路由、stripTopDir/extractFiles、包内结构读版本。不感知软件源。'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop')

    # 导出名单由 .psm1 的 Export-ModuleMember 决定。
    FunctionsToExport    = '*'
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    # 依赖方向由模块边界保证（下层不调用上层）；加载顺序不构成约束：
    # 函数文件只定义函数，跨模块调用在运行时才解析。
    # 刻意不使用 RequiredModules：那会让 Import-Module 去 PSModulePath 找模块，
    # 破坏「解压到任意目录即可运行」。
    #
    # 本模块调用到（运行时才需要）：
    #   Winst.Core
    #   Winst.Net
    #   Winst.Store
    #   Winst.Version

    PrivateData = @{
        PSData = @{
            Tags = @('winst', 'powershell51')
        }
    }
}
