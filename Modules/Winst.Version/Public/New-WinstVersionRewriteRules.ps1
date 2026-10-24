#Requires -Version 5.1

function New-WinstVersionRewriteRules {
    <#
    .SYNOPSIS
        解析清单里的 versionRewrite 声明并编译成规则。
    .DESCRIPTION
        版本号写法归一把「同一个版本的不同写法」对齐后再比较、展示与写台账，避免把同一个版本判成两个版本。
        清单里按**作用对象**分三处：`source.versionRewrite` 管源侧解析出的版本
        （如 GitHub tag 的 jdk8u504-b01）、`detect.versionRewrite` 管本机检测出的版本
        （如 java -version 的 1.8.0_504-b01）、`files[].versionRewrite` 只管那一个文件的地址模板展开。
        三处用的是同一个编译器，三种等价写法（一条规则只能用一种，可写成数组按顺序应用）：
          ① 写法模板（推荐）：{ "from": "jdk8u{u}-b{b}", "to": "1.8.0_{u}-b{b}" }
          ② 只去前缀 / 后缀：{ "stripPrefix": "jdk-" } / { "stripSuffix": "-beta" }
          ③ 正则（高级）：{ "pattern": "^jdk-", "replace": "" }
        三种写法最终都编译成 { pattern, replace } 后统一使用。
    .OUTPUTS
        @{ Ok; Rules = @( [ordered]@{ pattern; replace } ); Error; Declared }
    #>
    param($Spec)

    $result = @{ Ok = $true; Rules = @(); Error = ''; Declared = $false }
    if ($null -eq $Spec) { return $result }
    $result.Declared = $true

    $formHint = '版本改写要写成 { "from": "jdk8u{u}-b{b}", "to": "1.8.0_{u}-b{b}" }（推荐）、{ "stripPrefix": "jdk-" }（只去前缀）或 { "pattern": "…", "replace": "…" }（正则，高级）；一条规则只能用一种写法，多条规则写成数组按顺序应用'

    foreach ($item in @($Spec)) {
        if ($null -eq $item) { continue }
        if ($item -is [string]) {
            $result.Ok = $false
            $result.Error = $formHint
            return $result
        }

        $pattern = Get-EntryString -Entry $item -Key 'pattern'
        $replaceValue = Get-EntryValue -Entry $item -Key 'replace' -Default $null
        $templateFrom = Get-EntryString -Entry $item -Key 'from'
        $templateToValue = Get-EntryValue -Entry $item -Key 'to' -Default $null
        $stripPrefixValue = Get-EntryValue -Entry $item -Key 'stripPrefix' -Default $null
        $stripSuffixValue = Get-EntryValue -Entry $item -Key 'stripSuffix' -Default $null

        $stripPrefix = ''
        if ($null -ne $stripPrefixValue) { $stripPrefix = [string]$stripPrefixValue }
        $stripSuffix = ''
        if ($null -ne $stripSuffixValue) { $stripSuffix = [string]$stripSuffixValue }

        $formCount = 0
        if ($pattern -or $null -ne $replaceValue) { $formCount++ }
        if ($templateFrom -or $null -ne $templateToValue) { $formCount++ }
        if ($null -ne $stripPrefixValue -or $null -ne $stripSuffixValue) { $formCount++ }
        if ($formCount -gt 1) {
            $result.Ok = $false
            $result.Error = $formHint
            return $result
        }

        # ② 只去前缀 / 后缀（按字面量去掉，不涉及正则）
        if ($null -ne $stripPrefixValue -or $null -ne $stripSuffixValue) {
            if (-not $stripPrefix -and -not $stripSuffix) {
                $result.Ok = $false
                $result.Error = 'stripPrefix / stripSuffix 不能为空（要写出去掉的固定文字，如 "jdk-"）'
                return $result
            }
            if ($stripPrefix) {
                $result.Rules += [ordered]@{ pattern = ('^' + [regex]::Escape($stripPrefix)); replace = '' }
            }
            if ($stripSuffix) {
                $result.Rules += [ordered]@{ pattern = ([regex]::Escape($stripSuffix) + '$'); replace = '' }
            }
            continue
        }

        # ① 写法模板（推荐）
        if ($templateFrom -or $null -ne $templateToValue) {
            if (-not $templateFrom) {
                $result.Ok = $false
                $result.Error = '版本改写缺 from（要匹配的写法，如 jdk8u{u}-b{b}）'
                return $result
            }
            if ($null -eq $templateToValue) {
                $result.Ok = $false
                $result.Error = '版本改写缺 to（改写成什么写法；整段去掉时写空串 ""）'
                return $result
            }
            $compiled = ConvertTo-WinstVersionRewriteTemplate -From $templateFrom -To ([string]$templateToValue)
            if (-not $compiled.Ok) {
                $result.Ok = $false
                $result.Error = $compiled.Error
                return $result
            }
            $result.Rules += $compiled.Rule
            continue
        }

        # ③ 正则（高级）
        if (-not $pattern) {
            $result.Ok = $false
            $result.Error = $formHint
            return $result
        }
        if ($null -eq $replaceValue) {
            $result.Ok = $false
            $result.Error = '正则写法缺 replace（改写成什么；只去掉匹配部分时写空串 ""）'
            return $result
        }
        try {
            $null = New-Object System.Text.RegularExpressions.Regex($pattern)
        } catch {
            $result.Ok = $false
            $result.Error = ('版本改写的 pattern 不是合法的正则: {0}' -f $pattern)
            return $result
        }
        $result.Rules += [ordered]@{ pattern = $pattern; replace = [string]$replaceValue }
    }

    if ($result.Rules.Count -eq 0) {
        $result.Ok = $false
        $result.Error = 'versionRewrite 里没有有效规则'
    }
    return $result
}
