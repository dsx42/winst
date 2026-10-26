#Requires -Version 5.1

function Resolve-WinstDetectFiles {
    <#
    .SYNOPSIS
        把 detect.pathGlob 展开成本机绝对路径并取出**全部**命中的文件（fileVersion / markerFile / jsonFile 共用）。
    .DESCRIPTION
        pathGlob 可以带通配符、可以用 {installDir} / {installRoot} 占位符；命中多个时按 FullName 排序返回，
        保证结果稳定（Get-Item -Path 的多命中顺序本身不保证）。

        返回全部命中而不是第一个：同一个软件可能同时存在多个版本（如 .NET 运行时的
        `shared\Microsoft.WindowsDesktop.App\10.0.12` 与 `10.0.14`），只取排序第一的那个会
        把最新版本显示成最旧版本。调用方逐个识别版本后取最高的那个。

        注意：这里刻意用 Get-Item -Path 而不是 Get-ChildItem —— 前者支持清单里写的通配语义（含目录名通配），
        Get-ChildItem 不支持同样的语义。
    .OUTPUTS
        @{ Ok; Files; HitCount }；未声明 pathGlob / 无命中时 Ok = $false
    #>
    param(
        [hashtable]$Context,
        $Detect,
        [string]$InstallDir = ''
    )

    $result = @{ Ok = $false; Files = @(); HitCount = 0 }

    $glob = Expand-PlanPlaceholders -Value (Get-EntryString -Entry $Detect -Key 'pathGlob') `
        -InstallDir $InstallDir -InstallRoot $Context.InstallRoot
    if (-not $glob) { return $result }

    $hits = @()
    try { $hits = @(Get-Item -Path $glob -Force -ErrorAction SilentlyContinue) } catch { $hits = @() }
    if ($hits.Count -eq 0) { return $result }

    # 通配也可能命中目录（目录没有版本资源、也没有内容可读），只保留文件
    $files = @()
    foreach ($hit in $hits) {
        if ($null -eq $hit) { continue }
        if ($hit.PSIsContainer) { continue }
        $files += $hit
    }
    if ($files.Count -eq 0) { return $result }

    $result.Ok = $true
    $result.Files = @($files | Sort-Object -Property @{ Expression = { [string]$_.FullName } })
    $result.HitCount = $files.Count
    return $result
}
