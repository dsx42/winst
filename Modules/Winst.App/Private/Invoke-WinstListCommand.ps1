#Requires -Version 5.1

function Invoke-WinstListCommand {
    <#
    .SYNOPSIS
        CLI：winst list [--installed|--cached] —— 列出已安装的软件（--installed 为默认行为）。
    .DESCRIPTION
        无参数等价 `--installed`；`--cached` 列出已下载的安装包（与菜单「已下载包」共用 `Get-WinstCachedOverview`，
        同样给出「是否已安装 / 已装版本 / 已装能否升级 / 软件源里的版本 / 安装包能否更新」）；
        `--installed` 与 `--cached` 同时给出视为参数错误。
        两种列表的渲染分别由 Write-WinstCachedList / Write-WinstInstalledList 承担。
    .OUTPUTS
        [int] 退出码：0 成功 / 1 参数错误或安装记录读取失败
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string[]]$Arguments = @()
    )

    $onlyInstalled = $false
    $onlyCached = $false

    foreach ($token in @($Arguments)) {
        $text = [string]$token
        if ($text -eq '--installed') { $onlyInstalled = $true }
        elseif ($text -eq '--cached') { $onlyCached = $true }
        elseif (Try-Apply-WinstCommonCliFlag -Text $text) { }
        else {
            Write-Host ''
            Write-Host ('  未知参数: {0}' -f $text) -ForegroundColor Yellow
            Write-Host '  用法: winst list [--installed|--cached]' -ForegroundColor Gray
            return 1
        }
    }

    if ($onlyInstalled -and $onlyCached) {
        Write-Host ''
        Write-Host '  参数冲突: --installed 与 --cached 不能同时使用。' -ForegroundColor Yellow
        Write-Host '  用法: winst list [--installed|--cached]' -ForegroundColor Gray
        return 1
    }

    if ($onlyCached) {
        return (Write-WinstCachedList -Context $Context)
    }
    return (Write-WinstInstalledList -Context $Context)
}
