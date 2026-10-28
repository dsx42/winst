#Requires -Version 5.1

function Search-WinstRowsByKeywords {
    <#
    .SYNOPSIS
        按「整串优先、搜不到再拆分多关键字合并」的规则搜索软件源（菜单安装流程与 CLI search 共用）。
    .DESCRIPTION
        1. 把整串当一个关键字搜——软件名本身可能带空格（如「Eclipse Temurin JDK 21」），
           这样「一个名字」的输入行为不变；
        2. 整体没结果、且输入里含空格 / 逗号 / 顿号分隔的多个词时，按词分别搜索，
           按出现顺序合并、按 id 去重（同一软件只留一次），于是「jdk21 jdk25」「压缩 浏览器」
           这类输入能一次搜到多个软件，随后在列表里多选安装。
    .OUTPUTS
        @{ Rows; Keywords; Merged; HitKeywords }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Keyword
    )

    # 整串优先 / 拆词合并 / 按 id 去重都在 Merge-WinstKeywordSearch 里（与台账搜索同一套规则）。
    # @() 包住候选：函数返回空数组到调用方会变成 $null，再 @() 就成了「1 个 $null 条目」
    $merged = Merge-WinstKeywordSearch -Keyword $Keyword -Match {
        param([string]$Text)
        return @(Get-WinstSearchCatalog -Context $Context -Keyword $Text)
    }
    return @{
        Rows        = @(Sort-WinstRowsByGroup -Rows @($merged.Items))
        Keywords    = @($merged.Keywords)
        Merged      = [bool]$merged.Merged
        HitKeywords = @($merged.HitKeywords)
    }
}
