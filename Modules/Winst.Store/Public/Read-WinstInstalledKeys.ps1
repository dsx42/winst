#Requires -Version 5.1

function Read-WinstInstalledKeys {
    <#
    .SYNOPSIS
        读出安装台账里的全部软件 id（台账读失败时返回空数组，不抛异常）。
    .DESCRIPTION
        「读台账 → 取 Installed 的键」是大列表页刷新前的固定第一步，统一走这里。
        调用方要的只是「这次可能展示哪些已装软件」，读台账失败时按「没有已装软件」处理
        （后续刷新会自动跳过、渲染走空列表提示），因此这里吞掉 Error 而不上抛。
    .OUTPUTS
        [string[]] 已装软件的 id（台账里的键）
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    $read = Read-WinstState -InstallRoot $Context.InstallRoot
    if ($read.Error) { return @() }
    return @($read.State['Installed'].Keys | ForEach-Object { [string]$_ })
}
