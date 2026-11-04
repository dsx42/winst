#Requires -Version 5.1

function Test-WinstClickSteps {
    <#
    .SYNOPSIS
        校验点击序列的每一步（至少一个条件；href 能编译成匹配规则），返回错误文案或空串。
    .DESCRIPTION
        source.click、source.thenClick 与 source.hashClick 共用这套校验（SpecName 只影响文案）。
        未声明该键时 Get-EntryArray 返回空数组；调用方不要把 $null 当单步传入。
    #>
    param($Steps, [string]$SpecName)

    foreach ($step in @($Steps)) {
        if ($null -eq $step) { continue }
        $condition = ''
        foreach ($key in @('class', 'id', 'text', 'href')) {
            if ((Get-EntryString -Entry $step -Key $key).Trim()) { $condition = $key; break }
        }
        if (-not $condition) {
            return ('{0} 的每一步至少要写一个条件（class / id / text / href）' -f $SpecName)
        }
        $href = (Get-EntryString -Entry $step -Key 'href').Trim()
        if ($href) {
            $rule = New-MatchRule -Rule $href -Kind '链接地址'
            if (-not $rule.Ok) { return [string]$rule.Error }
        }
    }
    return ''
}
