#Requires -Version 5.1

function Test-AnchorMatches {
    <#
    .SYNOPSIS
        判断锚点是否满足 page 源的 link 条件。
    .DESCRIPTION
        class / id / text 为子串匹配（不区分大小写）；href 为通配匹配，
        多个条件同时给出时需全部满足。
    #>
    param($Anchor, $Spec)

    if ($null -eq $Spec) { return $true }

    $className = (Get-EntryString -Entry $Spec -Key 'class').Trim()
    if ($className) {
        $anchorClass = Get-EntryString -Entry $Anchor -Key 'Class'
        if (-not $anchorClass) { return $false }
        if ($anchorClass.IndexOf($className, [StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
    }

    $id = (Get-EntryString -Entry $Spec -Key 'id').Trim()
    if ($id) {
        $anchorId = Get-EntryString -Entry $Anchor -Key 'Id'
        if (-not $anchorId) { return $false }
        if ($anchorId.IndexOf($id, [StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
    }

    $text = (Get-EntryString -Entry $Spec -Key 'text').Trim()
    if ($text) {
        $anchorText = Get-EntryString -Entry $Anchor -Key 'Text'
        if (-not $anchorText) { return $false }
        if ($anchorText.IndexOf($text, [StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
    }

    $href = (Get-EntryString -Entry $Spec -Key 'href').Trim()
    if ($href) {
        $anchorHref = Get-EntryString -Entry $Anchor -Key 'Href'
        if (-not $anchorHref) { return $false }
        $rule = New-MatchRule -Rule $href -Kind '链接地址'
        if (-not $rule.Ok) { return $false }
        if (-not (Test-CompiledMatchRule -Rule $rule -Text $anchorHref)) { return $false }
    }

    return $true
}
