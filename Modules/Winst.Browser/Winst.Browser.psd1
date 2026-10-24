@{
    RootModule           = 'Winst.Browser.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = '9ac26506-e3ce-465b-953b-97fc64cb037c'
    Author               = 'winst'
    CompanyName          = 'winst'
    Copyright            = '(c) winst'
    Description          = '无头浏览器：系统自带 Edge、--dump-dom 抓页面、CDP 会话、点击步骤、下载事件捕获。按需加载。'
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

    PrivateData = @{
        PSData = @{
            Tags = @('winst', 'powershell51')
        }
    }
}
