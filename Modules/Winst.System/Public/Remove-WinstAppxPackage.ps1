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
        @{ Ok; Error }
    #>
    param($NameRule)

    $result = @{ Ok = $false; Error = '' }
    $packages = @(Get-WinstAppxPackagesMatching -NameRules $NameRule)
    if ($packages.Count -eq 0) {
        $result.Error = ('没有找到已安装的应用包（名称规则: {0}）' -f ((@($NameRule) | ForEach-Object { [string]$_ }) -join '、'))
        return $result
    }

    if (-not (Get-Command Remove-AppxPackage -ErrorAction SilentlyContinue)) {
        $result.Error = '系统里没有可用的应用包管理命令（Remove-AppxPackage）'
        return $result
    }

    $errors = @()
    foreach ($package in $packages) {
        try { $fullName = [string]$package.PackageFullName } catch { $fullName = '' }
        Write-Host ('    正在移除应用包: {0} …' -f $fullName) -ForegroundColor Gray
        try {
            Remove-AppxPackage -Package $fullName -ErrorAction Stop
        } catch {
            $errors += ('{0}（{1}）' -f $fullName, $_.Exception.Message)
        }
    }

    # 包已变化：Appx 快照失效
    $null = Set-WinstState -Name WinstAppxCache -Value ($null)

    if ($errors.Count -gt 0) {
        $result.Error = ('有 {0} 个应用包没有移除成功: {1}' -f $errors.Count, ($errors -join '；'))
        return $result
    }
    $result.Ok = $true
    return $result
}
