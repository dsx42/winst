#Requires -Version 5.1

function Select-WinstJsonVersionItems {
    <#
    .SYNOPSIS
        按完整版本原值过滤 JSON 候选；声明排序时只交付唯一最高项。
    #>
    param($Items, $Selection, [string]$Label)

    if (-not $Selection.FilterRule -and -not $Selection.Sort) {
        return @{ Error = ''; Items = @($Items) }
    }
    $selected = @()
    $highest = ''
    foreach ($item in @($Items)) {
        $found = Get-JsonNodeValue -Node $item -Key $Selection.VersionKey
        if (-not $found.Ok -or $null -eq $found.Node) { continue }
        # Text 会去掉首尾空白；过滤必须保留接口中的完整原值。
        $raw = [string]$found.Node
        if (-not $raw) { continue }
        if ($Selection.FilterRule -and -not (Test-CompiledMatchRule -Rule $Selection.FilterRule -Text $raw)) { continue }
        if (-not $Selection.Sort) { $selected += $item; continue }
        $version = Get-NormalizedVersionString -Value $raw
        if (-not (Get-WinstVersionFromText -Text $raw)) {
            return @{ Error = ($Label + ' 的版本字段不能用于 semver 排序：' + $raw); Items = @() }
        }
        $compare = 1
        if ($selected.Count -gt 0) { $compare = Compare-WinstVersion -A $version -B $highest }
        if ($compare -gt 0) { $selected = @($item); $highest = $version }
        elseif ($compare -eq 0) { $selected += $item }
    }
    if ($selected.Count -eq 0) {
        return @{ Error = ($Label + ' 没有符合版本规则的候选'); Items = @() }
    }
    if ($Selection.Sort -and $selected.Count -gt 1) {
        return @{ Error = ($Label + ' 的最高版本对应多个候选，无法唯一确定：' + $highest); Items = @() }
    }
    return @{ Error = ''; Items = @($selected) }
}
