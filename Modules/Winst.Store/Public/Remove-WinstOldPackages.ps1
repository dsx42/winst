#Requires -Version 5.1

function Remove-WinstOldPackages {
    <#
    .SYNOPSIS
        下载新版本成功后清理该 id 目录下的旧版本包文件。
    .OUTPUTS
        @( 被删除文件名 )
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        [string[]]$KeepFiles = @()
    )

    $removed = New-Object 'System.Collections.Generic.List[string]'
    # 删除入口再兜一层：id 不是单层目录名时（如 clean 传了 .. / 绝对路径）不猜、不越界删
    if (-not (Test-WinstSafePathSegment -Name $Id)) { return @() }
    $dir = Join-Path $Context.PkgDir $Id
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { return @() }

    foreach ($file in @(Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue)) {
        if ($KeepFiles -contains $file.Name) { continue }
        try {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            $removed.Add([string]$file.Name)
        } catch {
            # 旧包删除失败不影响本次安装
        }
    }
    return @($removed.ToArray())
}
