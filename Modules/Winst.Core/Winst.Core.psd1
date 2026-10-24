@{
    RootModule           = 'Winst.Core.psm1'
    ModuleVersion        = '1.0.0'
    GUID                 = '7d5434ce-9624-4dd9-b92d-008314e27e58'
    Author               = 'winst'
    CompanyName          = 'winst'
    Copyright            = '(c) winst'
    Description          = '基础运行时：上下文、配置、路径安全、原子文件 IO、JSON、参数转义、匹配规则、统一结果对象。'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop')

    # 导出名单由 .psm1 的 Export-ModuleMember 决定。
    FunctionsToExport    = '*'
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData = @{
        PSData = @{
            Tags = @('winst', 'powershell51')
        }
    }
}
