#Requires -Version 5.1
<#
    WinstConstants.ps1  (Winst.Core / Public)

    全模块共用的只读常量。

    为什么放在 Winst.Core
    ---------------------
    这些值被多个模块引用（例如内置源名被 Winst.Manifest、Winst.Catalog、
    Winst.Install、Winst.App 使用）。模块作用域变量在其它模块里看不到，
    因此以函数形式导出：

        Get-WinstProductVersion         产品版本
        Get-WinstOfficialManifestName   内置源名

    以函数形式提供，调用方拿到的值一律只读。
#>

function Get-WinstProductVersion {
    <#
    .SYNOPSIS
        winst 的产品版本号。

    .DESCRIPTION
        build.ps1 用它打印 release tag 与产物版本，值必须与 tag v<版本> 保持一致。
        发版前由开发者直接改这里的返回值；构建只读取、不写回。
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return '2026.10.24'
}

function Get-WinstOfficialRepoUrl {
    <#
    .SYNOPSIS
        产品仓库主页（winst 本体的源码与 release 所在仓库）。

    .DESCRIPTION
        它是产品主页，不是软件源仓库：软件源仓库见 Get-WinstOfficialManifestUrl。
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return 'https://github.com/dsx42/winst'
}

function Get-WinstOfficialManifestUrl {
    <#
    .SYNOPSIS
        内置清单的 raw 地址。

    .DESCRIPTION
        这是内置源的地址，用户不应修改或删除；
        Ensure-OfficialManifest 会把它改回原值。

        内置源仓库只存放清单文件，**没有 release**：软件包一律来自清单条目自己声明的
        `source.repo` / 地址，所以内置源不需要、也不会去读该仓库的 release。
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return 'https://raw.githubusercontent.com/dsx42/winst-manifest/main/manifest.json'
}

function Get-WinstOfficialManifestName {
    <#
    .SYNOPSIS
        内置源名，即内置源仓库的「用户名/仓库」。
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return 'dsx42/winst-manifest'
}

function Get-WinstRetiredManifestSourceList {
    <#
    .SYNOPSIS
        内置源的历史源名。

    .DESCRIPTION
        这些名字曾经是内置源，现在不再是。源列表里出现的同名字条目都是旧内置源留下的残留：
        Ensure-OfficialManifest 在自愈时把它们移除，只保留当前内置源；
        Add-RemoteManifest 也拒绝再用这些名字添加来源。
        历史源名是保留名，用户无法自行添加，因此按名字清理不会误删用户自己的来源。
    .OUTPUTS
        [string[]]
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    return @('dsx42/winst')
}

function Get-WinstLocalManifestName {
    <#
    .SYNOPSIS
        自动发现的本地清单所使用的固定源名。
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return 'local'
}

function Get-WinstManifestSourcesFileName {
    <#
    .SYNOPSIS
        共享源列表的文件名，位于 <pkgDir>\manifests 下。
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return 'sources.json'
}

function Get-WinstListFileName {
    <#
    .SYNOPSIS
        默认安装清单文件名。
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return 'setup.list'
}

function Get-WinstListKindText {
    <#
    .SYNOPSIS
        安装清单的展示名称。
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return '安装清单'
}

function Get-WinstMainFileDestNote {
    <#
    .SYNOPSIS
        清单给主包写了 dest 时追加的提示。
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return '主包会按条目类型安装到软件目录，软件源里给主包填写的 dest（落位路径）已忽略；dest 只用于附加文件。'
}

function Get-WinstHttpCacheTtlSec {
    <#
    .SYNOPSIS
        进程内 HTTP 响应缓存的 TTL（秒）。
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param()

    return 600
}

function Get-WinstStateSchemaVersion {
    <#
    .SYNOPSIS
        当前安装台账的结构版本。
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param()

    return 2
}

function Get-WinstDownloadEngineId {
    <#
    .SYNOPSIS
        下载引擎的清单 id。
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return 'FluxDown-CLI'
}

function Get-WinstDownloadEngineExe {
    <#
    .SYNOPSIS
        下载引擎的主程序。
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return 'fluxdown.exe'
}

function Get-WinstExtractEngineId {
    <#
    .SYNOPSIS
        解压引擎的清单 id。
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return '7-Zip-CLI'
}

function Get-WinstExtractEngineExe {
    <#
    .SYNOPSIS
        解压引擎的主程序。
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return '7z.exe'
}
