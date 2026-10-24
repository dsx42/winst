@{
    RootModule           = 'Winst.Catalog.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = '26161957-c9e3-4749-9bc2-2293a49fa0bf'
    Author               = 'winst'
    CompanyName          = 'winst'
    Copyright            = '(c) winst'
    Description          = '软件目录领域：六种来源解析、全流程计划构建、软件源刷新、搜索聚合、依赖图、列表视图事实。'
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
    #   Winst.Browser
    #   Winst.Version
    #   Winst.Manifest
    #   Winst.Store
    #   Winst.Engine

    PrivateData = @{
        PSData = @{
            Tags = @('winst', 'powershell51')
        }
    }
}
