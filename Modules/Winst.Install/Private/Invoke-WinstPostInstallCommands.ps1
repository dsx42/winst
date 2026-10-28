#Requires -Version 5.1

function Invoke-WinstPostInstallCommands {
    <#
    .SYNOPSIS
        执行 postInstall 命令（安装目录内相对路径或绝对路径；退出码不是 0 / 1641 / 3010 视为失败）。
    .DESCRIPTION
        执行细节见 Invoke-WinstCommandList。
    .OUTPUTS
        @{ Ok; Error }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Plan,
        [Parameter(Mandatory = $true)][string]$InstallDir
    )

    # Get-EntryArray 对「缺失 / 空数组」字段在管道里输出零个对象，调用处 (Get-EntryArray ...) 会变成 $null；
    # 这里用 @(...) 收集保证一定是数组，否则空 postInstall 的软件（如 7-Zip）会在 Mandatory 参数绑定上报
    # 「无法将参数绑定到参数"Commands"，因为该参数是空值」（全脚本其它 Get-EntryArray 调用点均已有 @() 包裹）
    return (Invoke-WinstCommandList -Commands @((Get-EntryArray -Entry $Plan -Key 'postInstall')) -Label '安装后命令' -InstallDir $InstallDir -InstallRoot $Context.InstallRoot)
}
