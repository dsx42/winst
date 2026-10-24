@{
    RootModule           = 'Winst.Logging.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'cf36d965-b2e0-40df-b218-fbed997351d7'
    Author               = 'winst'
    CompanyName          = 'winst'
    Copyright            = '(c) winst'
    Description          = '统一输出：分级消息、段落标题、缩进、颜色。业务模块不再直接 Write-Host。'
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

    PrivateData = @{
        PSData = @{
            Tags = @('winst', 'powershell51')
        }
    }
}
