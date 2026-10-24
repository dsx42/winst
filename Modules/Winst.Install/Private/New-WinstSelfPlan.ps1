#Requires -Version 5.1
<#
    New-WinstSelfPlan.ps1  (Winst.Install / Private)

    为「从本地包安装 winst 自身」构造执行计划。

    为什么必须现构造计划
    --------------------
    别处的计划都来自软件源：

        Get-WinstManifestAppPlan -> Resolve-AppSource -> New-ResolvedAppPlan

    那条路要求源可访问，而全新机器上的首次安装没有可访问的源：
    还没有刷新过目录，仓库也可能在用户运行安装脚本时尚未发布任何版本。
    依赖它会让引导过程变成循环。

    包已经在手上，定义是预先知道的。下面这块与 New-ResolvedAppPlan 产出的结构相同，
    填入真实清单条目为 id "winst" 声明的值：

        type        portable        目录形态：winst.ps1 + winst.cmd + Modules\
        mainExe     winst.cmd       随包提供，不生成
        keep        lists\ *.list   用户数据，升级后保留
        shortcuts   desktop + startMenu
        uninstall   portable-dir

    改动时必须与 manifest.json 保持一致。两者不一致时，用 `--from` 装的 winst
    会与从软件源装的 winst 行为不同；台账也会记下与实际落地不符的快捷方式或卸载方式。

    .OUTPUTS
        [ordered] 计划哈希表，键与 New-ResolvedAppPlan 产出的相同
#>
function New-WinstSelfPlan {
    <#
    .SYNOPSIS
        从本地包现构造 winst 自身的安装计划。

    .PARAMETER Version
        由 Get-WinstSelfSourceVersion 从包里读出的版本。

    .OUTPUTS
        [ordered] 计划哈希表
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Version
    )

    $plan = [ordered]@{
        id      = 'winst'
        name    = 'winst'
        type    = 'portable'
        version = $Version

        # ② 安装：整包解压到 <installRoot>\winst。
        #   stripTopDir = $false 是因为 release zip 本身就是扁平结构
        #   （winst.ps1 在根上），去掉顶层目录会把所有文件拆散。
        install = [ordered]@{
            method       = 'portable'
            stripTopDir  = $false
            portableMode = 'clean'
            keep         = @('lists/', '*.list')
            extractFiles = @()
            mainExe      = 'winst.cmd'
        }

        # ④ 系统项：winst 自身不写环境变量、不改进 PATH，只建快捷方式。
        env       = [ordered]@{}
        addToPath = @()

        shortcuts = [ordered]@{
            desktop   = $true
            startMenu = $true
        }

        # ⑦ 卸载：删安装目录即可。快捷方式与 PATH / 环境变量按台账里登记的
        #   实际记录回收（见 Get-WinstUninstallTargets），这里无需重复声明。
        uninstall = [ordered]@{
            method      = 'portable-dir'
            removeEnv   = @()
            removePaths = @()
        }

        # ⑥ 版本检测：快捷方式指向 winst.cmd，检测也走它，保证两边同一个入口。
        detect = [ordered]@{
            method      = 'cliVersion'
            exe         = 'winst.cmd'
            versionArgs = '-v'
            versionKind = 'semver'
        }

        notes = @()
        ok    = $true
    }

    return $plan
}
