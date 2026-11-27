#Requires -Version 5.1

function New-WinstCliOptions {
    <#
    .SYNOPSIS
        新建命令行全局选项。解析后的选项保存到 WinstOptions 状态项。
    #>
    return @{
        InstallRoot = ''
        PkgDir      = ''
        Proxy       = ''
        Offline     = $false
        DryRun      = $false
        Yes         = $false
        Verbose     = $false
    }
}
