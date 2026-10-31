#Requires -Version 5.1

function Remove-WinstAppxPackage {
    <#
    .SYNOPSIS
        移除应用包（MSIX / AppX）：按名称规则（字符串或数组）找到已安装的全部包，逐个用系统自带的
        Remove-AppxPackage 卸载。
    .DESCRIPTION
        一个软件可能对应不同包家族及架构；逐个移除清单名称规则明确允许的包。
        清单应限定所属系列与通道，并明确列出需要一并卸载的共享组件。
    .OUTPUTS
        @{ Ok; Error; PackageFullName; Removed; Failed }
    #>
    param($NameRule, [switch]$Quiet)

    $result = @{ Ok = $false; Error = ''; PackageFullName = ''; Removed = @(); Failed = @() }
    $packages = @(Get-WinstAppxPackagesMatching -NameRules $NameRule)
    if ($packages.Count -eq 0) {
        $result.Error = ('没有找到已安装的应用包（名称规则: {0}）' -f ((@($NameRule) | ForEach-Object { [string]$_ }) -join '、'))
        return $result
    }

    if (-not (Get-Command Remove-AppxPackage -ErrorAction SilentlyContinue)) {
        $result.Error = '系统里没有可用的应用包管理命令（Remove-AppxPackage）'
        return $result
    }

    foreach ($package in $packages) {
        $fullName = ''
        try { $fullName = [string]$package.PackageFullName } catch { $fullName = '' }
        if (-not $result.PackageFullName) { $result.PackageFullName = $fullName }
        if (-not $Quiet) { Write-Host ('    正在移除应用包: {0} …' -f $fullName) -ForegroundColor Gray }
        try {
            Remove-AppxPackage -Package $fullName -ErrorAction Stop
            $result.Removed += $fullName
        } catch {
            $result.Failed += [ordered]@{ PackageFullName = $fullName; Error = [string]$_.Exception.Message }
        }
    }

    # 包已变化：Appx 快照失效
    $null = Set-WinstState -Name WinstAppxCache -Value ($null)

    if (@($result.Failed).Count -gt 0) {
        $parts = @()
        foreach ($one in @($result.Failed)) { $parts += ('{0}（{1}）' -f $one['PackageFullName'], $one['Error']) }
        $result.Error = ('有 {0} 个应用包没有移除成功: {1}' -f @($result.Failed).Count, ($parts -join '；'))
        return $result
    }
    $result.Ok = $true
    return $result
}
