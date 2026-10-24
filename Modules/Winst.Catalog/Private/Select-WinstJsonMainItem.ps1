#Requires -Version 5.1

function Select-WinstJsonMainItem {
    <#
    .SYNOPSIS
        ③ 按 urlKey / files[0].file / match 条件挑出主包条目与下载地址。
    .OUTPUTS
        @{ Error; Item; Url }
    #>
    param($Items, $Declared, $MainLocator, $FileRule, [string]$ApiUrl, $Result)

    # match（字段路径 → 期望文本，如 distribution = opencode）按字段值过滤候选条目，
    # 多个条件全部满足才算命中；字段路径与 urlKey 同一套点分 / 引号段写法
    $matchPairs = @()
    if (@($Declared).Count -gt 0) {
        $matchSpec = Get-EntryValue -Entry $Declared[0] -Key 'match' -Default $null
        if ($null -ne $matchSpec) { $matchPairs = @(Get-WinstEntryPairs -Entry $matchSpec) }
    }

    $chosen = $null
    $downloadUrl = ''
    foreach ($item in @($Items)) {
        if ($matchPairs.Count -gt 0) {
            $matchOk = $true
            foreach ($pair in $matchPairs) {
                $found = Get-JsonNodeValue -Node $item -Key ([string]$pair[0])
                if (-not $found.Ok -or (([string]$found.Text).Trim() -ine (([string]$pair[1]).Trim()))) { $matchOk = $false; break }
            }
            if (-not $matchOk) { continue }
        }
        $found = Get-JsonNodeValue -Node $item -Key $MainLocator.UrlKey
        if (-not $found.Ok -or -not $found.Text) { continue }
        $candidate = ([string]$found.Text).Trim()
        if (-not $candidate) { continue }
        if ($FileRule -and -not (Test-FileRuleMatchesLink -Rule $FileRule -Text $candidate)) { continue }
        $chosen = $item
        $downloadUrl = $candidate
        break
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
    return @{ Error = ''; Item = $chosen; Url = $downloadUrl }
}
