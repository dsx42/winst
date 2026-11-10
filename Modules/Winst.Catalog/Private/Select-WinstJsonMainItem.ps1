#Requires -Version 5.1

function Select-WinstJsonMainItem {
    <#
    .SYNOPSIS
        ③ 按 urlKey / files[0].file / match 条件挑出主包条目与下载地址。
    .OUTPUTS
        @{ Error; Item; FileItem; FileItems; Url }
    #>
    param($Items, $Declared, $MainLocator, $FileRule, [string]$ApiUrl, $Result)

    # match（字段路径 → 期望文本，如 distribution = opencode）按字段值过滤候选条目，
    # 多个条件全部满足才算命中；字段路径与 urlKey 同一套点分 / 引号段写法
    $matchPairs = @()
    if (@($Declared).Count -gt 0) {
        $matchSpec = Get-EntryValue -Entry $Declared[0] -Key 'match' -Default $null
        if ($null -ne $matchSpec) { $matchPairs = @(Get-WinstEntryPairs -Entry $matchSpec) }
    }

    $itemsKey = (Get-EntryString -Entry $Declared[0] -Key 'itemsKey').Trim()
    if ($itemsKey -and @($Items).Count -ne 1) {
        return @{ Error = 'JSON 主包的 itemsKey 必须在唯一发布项中选择，请配置版本过滤或排序'; Item = $null; FileItem = $null; Url = '' }
    }

    $chosen = $null
    $chosenFile = $null
    $downloadUrl = ''
    foreach ($item in @($Items)) {
        $fileItems = @($item)
        if ($itemsKey) {
            $container = Get-JsonNodeValue -Node $item -Key $itemsKey
            if (-not $container.Ok) {
                return @{ Error = ('JSON 主包找不到文件集合字段：' + $itemsKey); Item = $null; FileItem = $null; Url = '' }
            }
            $fileItems = @($container.Node)
        }
        foreach ($fileItem in $fileItems) {
            if ($matchPairs.Count -gt 0) {
                $matchOk = $true
                foreach ($pair in $matchPairs) {
                    $found = Get-JsonNodeValue -Node $fileItem -Key ([string]$pair[0])
                    if (-not $found.Ok -or (([string]$found.Text).Trim() -ine (([string]$pair[1]).Trim()))) { $matchOk = $false; break }
                }
                if (-not $matchOk) { continue }
            }
            $found = Get-JsonNodeValue -Node $fileItem -Key $MainLocator.UrlKey
            if (-not $found.Ok -or -not $found.Text) { continue }
            $candidate = ([string]$found.Text).Trim()
            if (-not $candidate) { continue }
            if ($FileRule -and -not (Test-FileRuleMatchesLink -Rule $FileRule -Text $candidate)) { continue }
            if ($null -ne $chosen -and $itemsKey) {
                return @{ Error = ('JSON 主包的文件集合匹配到多个安装包：' + $itemsKey); Item = $null; FileItem = $null; Url = '' }
            }
            $chosen = $item
            $chosenFile = $fileItem
            $downloadUrl = $candidate
            if (-not $itemsKey) { break }
        }
        if ($null -ne $chosen) { break }
    }
    if ($null -eq $chosen) {
        $filterText = ''
        if ($FileRule) { $filterText = ('（文件名规则「{0}」）' -f $FileRule.Source) }
        return @{ Error = ('JSON 接口 {0} 里没有取到可用的下载地址（字段 {1}）{2}；可能是接口变更，需要更新软件源' -f `
                    $ApiUrl, $MainLocator.UrlKey, $filterText); Item = $null; Url = '' }
    }
    if (@($Items).Count -gt 1 -and -not $FileRule) {
        $Result.Notes += ('接口里有 {0} 条内容，已取第一条；如需指定，可用 files[0].file 按文件名挑选。' -f @($Items).Count)
    }
    if (-not (Test-UrlText -Text $downloadUrl)) {
        return @{ Error = ('JSON 接口里取到的下载地址不是完整地址: {0}' -f $downloadUrl); Item = $null; Url = '' }
    }
    return @{ Error = ''; Item = $chosen; FileItem = $chosenFile; FileItems = $fileItems; Url = $downloadUrl }
}
