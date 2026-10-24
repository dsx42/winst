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

    foreach ($item in @(Get-RemoteManifestList -PkgDir $Context.PkgDir)) {
        $name = [string]$item['name']
        if (-not $name) { continue }
        $sources += [ordered]@{
            name      = $name
            kind      = 'remote'
            url       = [string]$item['url']
            files     = @()
            isLocal   = $false
            isBuiltin = ($name -ieq (Get-WinstOfficialManifestName))
        }
    }

    return @($sources)
}
