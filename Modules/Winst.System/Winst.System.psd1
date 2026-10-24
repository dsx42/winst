@{
    RootModule           = 'Winst.System.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = 'dd9a4234-051f-4491-a38e-947aa24bf86e'
    Author               = 'winst'
    CompanyName          = 'winst'
    Copyright            = '(c) winst'
    Description          = '操作系统集成原语：注册表卸载项、Appx 包、环境变量、PATH、快捷方式、进程快照、目录删除。'
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
    #   Winst.Version

    PrivateData = @{
        PSData = @{
            Tags = @('winst', 'powershell51')
        }
    }
}
