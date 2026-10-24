#Requires -Version 5.1

function Show-Banner {
    <#
    .SYNOPSIS
        渲染顶部横幅：版本号、软件安装到、安装包位置（含来源标记）。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context
    )

    $titleLine = ' winst · 软件安装与管理  v{0}' -f (Get-WinstProductVersion)
    $installLine = ' 软件安装到: {0}  {1}' -f $Context.InstallRoot, $Context.InstallRootLabel
    $pkgLine = ' 安装包位置: {0}  {1}' -f $Context.PkgDir, $Context.PkgDirLabel

    # 分隔线宽度跟随最长内容行（按终端显示宽度计算），避免文字超出分隔线
    $ruleWidth = 42
    foreach ($line in @($titleLine, $installLine, $pkgLine)) {
        $lineWidth = Get-DisplayWidth -Text $line
        if ($lineWidth -gt $ruleWidth) { $ruleWidth = $lineWidth }
    }
    $rule = '=' * $ruleWidth

    Write-Host ''
    Write-Host $rule -ForegroundColor DarkCyan
    Write-Host $titleLine -ForegroundColor White
    Write-Host $installLine -ForegroundColor Gray
    Write-Host $pkgLine -ForegroundColor Gray
    Write-Host $rule -ForegroundColor DarkCyan
}
