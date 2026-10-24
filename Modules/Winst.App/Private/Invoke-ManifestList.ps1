#Requires -Version 5.1

function Invoke-ManifestList {
    <#
    .SYNOPSIS
        列出全部软件源及其清单版本 / 更新时间 / 软件清单概况。
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    Write-Section '软件源列表'

    $sources = @(Get-ManifestSourceList -Context $Context)
    if ($sources.Count -eq 0) {
        Write-Host '  暂无软件源。' -ForegroundColor Yellow
        return
    }

    $index = 0
    foreach ($source in $sources) {
        $index++
        Write-ManifestSourceInfo -Context $Context -Source $source -Index $index
    }

    # 同 id 冲突提示：各软件源之间没有覆盖关系，同一 id 出现在多个源时留待下载 / 安装时选择来源
    # 只统计「可用」条目——解析失败的条目本来就装不了，不构成需要用户选择的冲突
    $idSources = New-Object 'System.Collections.Hashtable' ([StringComparer]::Ordinal)
    foreach ($source in $sources) {
        $sourceName = [string]$source['name']
        foreach ($app in @(Get-ManifestResolvedApps -PkgDir $Context.PkgDir -Name $sourceName)) {
            if (-not (Get-EntryBool -Entry $app -Key 'ok')) { continue }
            $appId = Get-EntryString -Entry $app -Key 'id'
            if (-not $appId) { continue }
            if (-not $idSources.ContainsKey($appId)) { $idSources[$appId] = @() }
            $idSources[$appId] = @($idSources[$appId] + $sourceName)
        }
    }
    $conflicts = @()
    foreach ($appId in @($idSources.Keys)) {
        $owners = @($idSources[$appId])
        if ($owners.Count -gt 1) { $conflicts += ('{0}（{1}）' -f $appId, ($owners -join '、')) }
    }

    Write-Host ''
    Write-Host ('  共 {0} 个软件源；各软件源之间没有覆盖关系。' -f $sources.Count) -ForegroundColor DarkGray
    if ($conflicts.Count -gt 0) {
        Write-Host ('  提示: {0} 个软件在多个软件源里都有，下载 / 安装时会让你选择来源。' -f $conflicts.Count) -ForegroundColor DarkYellow
        foreach ($text in @($conflicts | Sort-Object)) {
            Write-Host ('    - {0}' -f $text) -ForegroundColor DarkGray
        }
    }
}
