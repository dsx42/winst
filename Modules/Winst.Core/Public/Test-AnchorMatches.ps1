#Requires -Version 5.1

function Test-AnchorMatches {
    <#
    .SYNOPSIS
        判断锚点是否满足 page 源的 link 条件。
    .DESCRIPTION
        class / id / text 为子串匹配（不区分大小写）；href 为通配匹配，
        多个条件同时给出时需全部满足。
    #>
    param($Anchor, $Spec, $HrefRule = $null)

    if ($null -eq $Spec) { return $true }

    foreach ($field in @('Class', 'Id', 'Text')) {
        $needle = (Get-EntryString -Entry $Spec -Key $field.ToLowerInvariant()).Trim()
        if ($needle) {
            $value = Get-EntryString -Entry $Anchor -Key $field
            if ($value.IndexOf($needle, [StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
        }
    }

    $href = (Get-EntryString -Entry $Spec -Key 'href').Trim()
    if ($href) {
        $anchorHref = Get-EntryString -Entry $Anchor -Key 'Href'
        if (-not $anchorHref) { return $false }
        $rule = $HrefRule
        if ($null -eq $rule) { $rule = New-MatchRule -Rule $href -Kind '链接地址' }
        if (-not $rule.Ok) { return $false }
        if (-not (Test-CompiledMatchRule -Rule $rule -Text $anchorHref)) { return $false }
    }

    return $true
}
