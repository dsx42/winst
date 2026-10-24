#Requires -Version 5.1

function New-WinstCliOptions {
    <#
    .SYNOPSIS
        新建命令行的全局选项对象（与 $script:WinstOptions 同一结构）。
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
