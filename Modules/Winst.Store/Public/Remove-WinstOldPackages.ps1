#Requires -Version 5.1

function Remove-WinstOldPackages {
    <#
    .SYNOPSIS
        下载新版本成功后清理该 id 目录下的旧版本包文件。
    .OUTPUTS
        @{ Removed = @(被删除文件名); Failed = @(失败原因) }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        [string[]]$KeepFiles = @()
    )

    $removed = New-Object 'System.Collections.Generic.List[string]'
    $failed = @()
    # 删除入口再兜一层：id 不是单层目录名时（如 clean 传了 .. / 绝对路径）不猜、不越界删
    if (-not (Test-WinstSafePathSegment -Name $Id)) { throw ('软件 id 不合法：{0}' -f $Id) }
    $dir = Join-WinstPath $Context.PkgDir $Id
    Assert-WinstSafeWritePath -Path $dir -Directory
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return @{ Removed = @(); Failed = @() } }

    foreach ($file in @(Get-ChildItem -LiteralPath $dir -File -ErrorAction Stop)) {
        if ($KeepFiles -contains $file.Name) { continue }
        try {
            Assert-WinstSafeWritePath -Path $file.FullName
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            $removed.Add([string]$file.Name)
        } catch {
            $failed += ('{0}: {1}' -f $file.Name, $_.Exception.Message)
            Write-Warning ('旧包未能清理：{0}（{1}）' -f $file.FullName, $_.Exception.Message)
        }
    }
    return @{ Removed = @($removed.ToArray()); Failed = @($failed) }
}
