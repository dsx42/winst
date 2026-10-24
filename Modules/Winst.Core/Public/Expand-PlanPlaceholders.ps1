#Requires -Version 5.1

function Expand-PlanPlaceholders {
    <#
    .SYNOPSIS
        把软件清单里的 {installDir} / {installRoot} 展开为本机实际路径，便于普通用户直接阅读。
    .DESCRIPTION
        只做整体替换、不改动其它内容；%VAR% 形式的引用按原样保留（其含义是「跟随该环境变量的值」）。
    #>
    param(
        [string]$Value,
        [string]$InstallDir,
        [string]$InstallRoot = ''
    )

    if ($null -eq $Value) { return '' }
    $text = [string]$Value
    if ($InstallDir) { $text = $text.Replace('{installDir}', $InstallDir) }
    if ($InstallRoot) { $text = $text.Replace('{installRoot}', $InstallRoot) }
    return $text
}
