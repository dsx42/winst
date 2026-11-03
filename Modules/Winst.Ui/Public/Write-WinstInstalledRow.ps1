#Requires -Version 5.1

function Write-WinstInstalledRow {
    <#
    .SYNOPSIS
        输出已准备好的已安装软件列表行。
    #>
    param($Item, [int]$Number)

    Write-WinstListItemIdentity -Item $item -Number $number
    Write-Host ('    版本 {0}' -f [string]$item['Version']) -NoNewline -ForegroundColor Gray
    if ([bool]$item['HasUpdate']) {
        Write-Host ('  {0}' -f [string]$item['UpdateHint']) -NoNewline -ForegroundColor Green
    }
    if ([bool]$item['DirMissing']) {
        Write-Host '  [安装目录不存在]' -NoNewline -ForegroundColor Yellow
    }
    Write-Host ''
    # 本机并存的旧版本：列表里就要能看见，用户才知道可以进去清理（详情页提供卸载选项）
    if ([bool]$item['HasOldVersions']) {
        Write-Host ('     还并存旧版本 {0}  [进详情可清理]' -f [string]$item['OldVersionsText']) -ForegroundColor DarkYellow
    }
    if ([string]$item['InstallDir']) {
        Write-Host ('     安装位置: {0}' -f [string]$item['InstallDir']) -ForegroundColor Gray
    } else {
        Write-Host '     安装位置: （未记录）' -ForegroundColor DarkGray
    }
    # 已装软件的来源（安装时用的是哪个软件源；可更新时 UpdateHint 里也标出更新来自哪个源）
    $noteParts = @([string]$item['ManagedText'])
    if ([string]$item['ManifestOrigin']) {
        $noteParts += ('来自软件源: {0}' -f [string]$item['ManifestOrigin'])
    } else {
        $noteParts += '来自软件源: （未记录）'
    }
    if (-not [bool]$item['InCatalog']) { $noteParts += '软件源里没有这个软件' }
    Write-Host ('     {0}' -f ($noteParts -join ' · ')) -ForegroundColor DarkGray
    if ([bool]$item['InCatalog'] -and [string]$item['SourceText']) {
        Write-Host ('     软件源里的版本: {0}' -f [string]$item['SourceText']) -ForegroundColor DarkGray
    }
    Write-WinstCompanionVersions -Item $Item
}
