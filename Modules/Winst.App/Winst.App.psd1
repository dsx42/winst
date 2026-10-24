@{
    RootModule           = 'Winst.App.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = '2685d981-f113-4e74-a8c6-e0512d176a19'
    Author               = 'winst'
    CompanyName          = 'winst'
    Copyright            = '(c) winst'
    Description          = '组合根：CLI 参数解析与分发、菜单流程编排、结果到退出码映射。'
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
    #   Winst.Logging
    #   Winst.Ui
    #   Winst.Version
    #   Winst.Manifest
    #   Winst.Catalog
    #   Winst.Store
    #   Winst.Install

    PrivateData = @{
        PSData = @{
            Tags = @('winst', 'powershell51')
        }
    }
}
