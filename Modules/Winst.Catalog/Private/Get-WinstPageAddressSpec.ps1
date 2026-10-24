#Requires -Version 5.1

function Get-WinstPageAddressSpec {
    <#
    .SYNOPSIS
        校验 page 源的 files[] 声明与 link / click / thenClick / thenLink 组合，返回取址规格。
    .OUTPUTS
        @{ Error; Item; Declared; FileRule; LinkSpec; ClickSpec; ThenClickSpec; ThenLinkSpec }
    #>
    param($Source, $Result)

    $item = $null
    $fileRule = $null
    $declared = @(Get-SourceFileDeclarations -Source $Source)
    if ($declared.Count -gt 0) {
        $item = $declared[0]
        $locator = Get-SourceFileLocator -Item $item -Kind 'page'
        if ($locator.Error) { return @{ Error = [string]$locator.Error } }
        if ($locator.Url) {
            return @{ Error = '下载页来源的地址由页面自动提取，不能填写 url；如需在其中挑出指定的文件，请用 file（通配，如 "*.exe"）' }
        }
        # 下载页来源只有主包一条：dest 同样无意义，走统一判定（有填写时记提示）
        $null = Get-WinstFileDest -Item $item -Index 1 -Result $Result

        if ($locator.File) {
            $fileRule = New-MatchRule -Rule (Get-MatchRuleText -Rule $locator.File) -Kind '文件名'
            if (-not $fileRule.Ok) { return @{ Error = [string]$fileRule.Error } }
        }
    }

    $linkSpec = Get-EntryValue -Entry $Source -Key 'link' -Default $null
    $clickSpec = Get-EntryValue -Entry $Source -Key 'click' -Default $null
    $thenClickSpec = Get-EntryValue -Entry $Source -Key 'thenClick' -Default $null
    $thenLinkSpec = Get-EntryValue -Entry $Source -Key 'thenLink' -Default $null
    if ($null -ne $linkSpec -and $null -ne $clickSpec) {
        return @{ Error = 'source.link 与 source.click 只能写一个：link 是在页面锚点里找地址，click 是点按钮让浏览器把地址交出来' }
    }
    if ($null -eq $linkSpec -and $null -eq $clickSpec) {
        return @{ Error = '软件源里没有填写下载按钮的识别方式（source.link 或 source.click，可用 class / id / text / href）' }
    }
    # 空规则（{} 或 href: ""）会让 Test-AnchorMatches 对**所有**锚点返回 true，进而把页面上第一个
    # 链接当成下载地址：入口处直接拒绝，别让错误沉默地变成「下错文件」。
    if ($null -ne $linkSpec) {
        $hasCondition = $false
        foreach ($key in @('class', 'id', 'text', 'href')) {
            if ((Get-EntryString -Entry $linkSpec -Key $key).Trim()) { $hasCondition = $true; break }
        }
        if (-not $hasCondition) {
            return @{ Error = 'source.link 至少要写一个条件（class / id / text / href），否则会命中页面上的第一个链接' }
        }
    }
    if ($null -ne $thenClickSpec -and $null -eq $linkSpec) {
        return @{ Error = 'source.thenClick 要和 source.link 搭配：link 在页面上找到中间页地址，thenClick 再用无头浏览器打开它、点按钮取真正的下载地址' }
    }
    if ($null -ne $thenClickSpec -and $null -ne $clickSpec) {
        return @{ Error = 'source.thenClick 与 source.click 不能同时写：click 是在本页点按钮取地址，thenClick 是进 link 找到的中间页再点按钮' }
    }
    if ($null -ne $thenLinkSpec -and $null -eq $linkSpec) {
        return @{ Error = 'source.thenLink 要和 source.link 搭配：link 在页面上找到中转页地址，thenLink 再抓取它的 HTML、按 link 规则定位真正的下载地址' }
    }
    if ($null -ne $thenLinkSpec -and $null -ne $thenClickSpec) {
        return @{ Error = 'source.thenLink 与 source.thenClick 只能写一个：两者都是「进 link 找到的中间页再取地址」——thenLink 抓中间页 HTML 重新定位链接，thenClick 用无头浏览器点按钮取下载事件' }
    }
    $thenLinkLocator = $null
    if ($null -ne $thenLinkSpec) {
        $thenLinkLocator = Get-EntryValue -Entry $thenLinkSpec -Key 'link' -Default $null
        if ($null -ne $thenLinkLocator) {
            $hasCondition = $false
            foreach ($key in @('class', 'id', 'text', 'href')) {
                if ((Get-EntryString -Entry $thenLinkLocator -Key $key).Trim()) { $hasCondition = $true; break }
            }
            if (-not $hasCondition) {
                return @{ Error = 'source.thenLink.link 至少要写一个条件（class / id / text / href），否则会命中中转页上的第一个链接' }
            }
        } elseif ($null -eq $fileRule) {
            return @{ Error = 'source.thenLink 需要 link（在中转页上定位下载地址的规则，写法同 source.link），或 files[0].file（按文件名通配过滤中转页的链接）——两者都没有时无从挑出下载地址' }
        }
    }

    $stepError = Test-WinstClickSteps -Steps (Get-EntryArray -Entry $Source -Key 'thenClick') -SpecName 'source.thenClick'
    if ($stepError) { return @{ Error = $stepError } }
    $clickStepError = Test-WinstClickSteps -Steps (Get-EntryArray -Entry $Source -Key 'click') -SpecName 'source.click'
    if ($clickStepError) { return @{ Error = $clickStepError } }

    if ($null -ne $linkSpec -and (Get-EntryString -Entry $linkSpec -Key 'href').Trim()) {
        $hrefRule = New-MatchRule -Rule (Get-EntryString -Entry $linkSpec -Key 'href') -Kind '链接地址'
        if (-not $hrefRule.Ok) { return @{ Error = [string]$hrefRule.Error } }
    }

    return @{
        Error         = ''
        Item          = $item
        Declared      = $declared
        FileRule      = $fileRule
        LinkSpec      = $linkSpec
        ClickSpec     = $clickSpec
        ThenClickSpec = $thenClickSpec
        ThenLinkSpec  = $thenLinkSpec
    }
}
