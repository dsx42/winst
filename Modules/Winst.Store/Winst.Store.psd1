@{
    RootModule           = 'Winst.Store.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = '94742c45-d8d8-4434-8694-fa6ebd474935'
    Author               = 'winst'
    CompanyName          = 'winst'
    Copyright            = '(c) winst'
    Description          = '持久化与完整性：安装台账、安装包缓存索引、文件记账、期望摘要、完整性校验、缓存新鲜度、安装清单文件读写。'
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
    #   Winst.Net
    #   Winst.System

    PrivateData = @{
        PSData = @{
            Tags = @('winst', 'powershell51')
        }
    }
}
