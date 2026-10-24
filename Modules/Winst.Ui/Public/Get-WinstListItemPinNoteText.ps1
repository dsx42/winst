#Requires -Version 5.1

function Get-WinstListItemPinNoteText {
    <#
    .SYNOPSIS
        清单条目的「清单项」展示文本：未指定版本时给出软件源最高版本。
    #>
    param($Item)

    if ([string]$Item['PinnedVersion']) { return [string]$Item['PinnedVersion'] }
    if ([string]$Item['BestVersion']) { return ('未指定版本（软件源里最高 {0}）' -f [string]$Item['BestVersion']) }
    return '未指定版本'
}
