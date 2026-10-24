#Requires -Version 5.1

function Resolve-WinstDetectFirstFile {
    <#
    .SYNOPSIS
        把 detect.pathGlob 展开成本机绝对路径并取出第一个命中文件（fileVersion / markerFile / jsonFile 共用）。
    .DESCRIPTION
        pathGlob 可以带通配符、可以用 {installDir} / {installRoot} 占位符；命中多个时按 FullName 排序后取第一个，
        保证结果稳定（Get-Item -Path 的多命中顺序本身不保证）。
        注意：这里刻意用 Get-Item -Path 而不是 Get-ChildItem —— 前者支持清单里写的通配语义（含目录名通配），
        Get-ChildItem 不支持同样的语义。
    .OUTPUTS
        @{ Ok; File; HitCount }；未声明 pathGlob / 无命中时 Ok = $false
    #>
    param(
        [hashtable]$Context,
        $Detect,
        [string]$InstallDir = ''
    )

    $result = @{ Ok = $false; File = $null; HitCount = 0 }

    $glob = Expand-PlanPlaceholders -Value (Get-EntryString -Entry $Detect -Key 'pathGlob') `
        -InstallDir $InstallDir -InstallRoot $Context.InstallRoot
    if (-not $glob) { return $result }

    $hits = @()
    try { $hits = @(Get-Item -Path $glob -Force -ErrorAction SilentlyContinue) } catch { $hits = @() }
    if ($hits.Count -eq 0) { return $result }

    $sorted = @($hits | Sort-Object -Property @{ Expression = { [string]$_.FullName } })
    $result.Ok = $true
    $result.File = $sorted[0]
    $result.HitCount = $hits.Count
    return $result
}
