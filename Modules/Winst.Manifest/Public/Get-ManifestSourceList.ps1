#Requires -Version 5.1

function Get-ManifestSourceList {
    <#
    .SYNOPSIS
        返回全部软件源（本地清单 + 内置源 + 用户添加的 GitHub 仓库源）。
    .OUTPUTS
        @( @{ name; kind（local|remote）; url; files[]; isLocal; isBuiltin } )
    .DESCRIPTION
        软件源之间**没有覆盖关系**：本地清单、内置源与用户添加的源彼此独立，
        同一 id 出现在多个源时留待下载 / 安装时由用户选择来源。
        本地清单是自动识别的（脚本同目录的清单文件，见 Get-LocalManifestFiles），
        不写入 sources.json，也不能添加 / 删除。

        内置源**总是出现在返回值里**：sources.json 缺失（全新机器、安装包位置刚换过）时
        直接从内置源常量补进列表（本地清单之后、其它远程源之前），不让「还没写过源列表」变成「内置源不存在」——
        否则全新机器上 `install` / `search` / `bundle install` 一律报「软件源里没有这个软件」，
        必须先进一次「管理软件源」才能用。补齐只发生在内存里，落盘仍由
        Ensure-OfficialManifest 在各写入点完成（只读调用 / 预览 / 离线不写文件）。
    #>
    param([Parameter(Mandatory = $true)][hashtable]$Context)

    $sources = @()

    $localFiles = @(Get-LocalManifestFiles -PkgDir $Context.PkgDir)
    if ($localFiles.Count -gt 0) {
        $sources += [ordered]@{
            name      = (Get-WinstLocalManifestName)
            kind      = 'local'
            url       = ''
            files     = $localFiles
            isLocal   = $true
            isBuiltin = $false
        }
    }

    $officialName = Get-WinstOfficialManifestName
    $hasOfficial = $false
    foreach ($item in @(Get-RemoteManifestList -PkgDir $Context.PkgDir)) {
        $name = [string]$item['name']
        if (-not $name) { continue }
        if ($name -ieq $officialName) { $hasOfficial = $true }
        $sources += [ordered]@{
            name      = $name
            kind      = 'remote'
            url       = [string]$item['url']
            files     = @()
            isLocal   = $false
            isBuiltin = ($name -ieq $officialName)
        }
    }

    if (-not $hasOfficial) {
        $officialEntry = [ordered]@{
            name      = $officialName
            kind      = 'remote'
            url       = (Get-WinstOfficialManifestUrl)
            files     = @()
            isLocal   = $false
            isBuiltin = $true
        }
        $localOnly = @($sources | Where-Object { [bool]$_['isLocal'] })
        $others = @($sources | Where-Object { -not [bool]$_['isLocal'] })
        $sources = @($localOnly) + @($officialEntry) + @($others)
    }

    return @($sources)
}
