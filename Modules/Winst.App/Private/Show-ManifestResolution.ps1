#Requires -Version 5.1

function Show-ManifestResolution {
    <#
    .SYNOPSIS
        渲染某软件源的软件清单：逐软件七个阶段 + 末尾汇总（有误项单列原因）。
    .DESCRIPTION
        面向普通用户：路径按本机设置展开为实际值，术语使用「软件清单」「安装包」等日常说法。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Name,
        $Apps = $null,
        [switch]$Preview
    )

    if ($null -eq $Apps) { $Apps = @(Get-ManifestResolvedApps -PkgDir $Context.PkgDir -Name $Name) }
    $apps = @($Apps)

    Write-Section ('软件清单 · {0}' -f $Name)

    if ($apps.Count -eq 0) {
        Write-Host '  还没读取过这个软件源的软件清单，请先刷新软件源。' -ForegroundColor DarkGray
        return
    }


    Write-Host ('  下面显示每个软件装到哪里、怎么用、以后怎么卸载。' ) -ForegroundColor DarkGray
    Write-Host ('  路径已按本机设置展开（软件安装到 {0}）；带 %XXX% 的内容表示会跟随该环境变量，切换变量即可整体切换版本。' -f $Context.InstallRoot) -ForegroundColor DarkGray

    $desktopDir = ''
    try { $desktopDir = [Environment]::GetFolderPath('Desktop') } catch { $desktopDir = '' }
    $startMenuDir = ''
    if ($env:APPDATA) { $startMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs' }

    $succeeded = 0
    $failed = 0
    $index = 0
    foreach ($app in $apps) {
        $index++
        if (Get-EntryBool -Entry $app -Key 'ok') { $succeeded++ } else { $failed++ }
        Show-ResolvedAppPlan -Plan $app -Index $index -Total $apps.Count -SourceName $Name `
            -InstallRoot $Context.InstallRoot -PkgDir $Context.PkgDir `
            -DesktopDir $desktopDir -StartMenuDir $startMenuDir -Context $Context
    }

    Write-Host ''
    Write-Host ('  ' + ('─' * 66)) -ForegroundColor DarkGray
    $summaryColor = 'Green'
    if ($failed -gt 0) { $summaryColor = 'Red' }
    Write-Host ('  汇总: 共 {0} 个软件，可用 {1} 个，有误 {2} 个' -f $apps.Count, $succeeded, $failed) -ForegroundColor $summaryColor

    if ($failed -gt 0) {
        Write-Host '  以下软件没能读取到可用版本:' -ForegroundColor Red
        foreach ($app in $apps) {
            if (Get-EntryBool -Entry $app -Key 'ok') { continue }
            Write-Host ('    - {0}（{1}）: {2}' -f `
                (Get-EntryString -Entry $app -Key 'name'), `
                (Get-EntryString -Entry $app -Key 'id'), `
                (Get-EntryString -Entry $app -Key 'error')) -ForegroundColor Red
        }
    }

    $metaPath = Get-ManifestMetaPath -PkgDir $Context.PkgDir -Name $Name
    if ($Preview) {
        Write-Host ('  以上为预览结果，尚未保存（保存位置: {0}）' -f $metaPath) -ForegroundColor DarkGray
    } else {
        Write-Host ('  以上软件清单已保存到: {0}' -f $metaPath) -ForegroundColor DarkGray
    }
}
