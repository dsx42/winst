#Requires -Version 5.1

function Get-VersionFromSourceText {
    <#
    .SYNOPSIS
        从来源文本（页面 HTML / 下载地址）里识别版本号：versionBetween 截取 → versionKind 提取（可组合）。
    .DESCRIPTION
        声明方式：
          ① 只写 versionBetween —— 取「两个标记之间」的内容即版本；
          ② 只写 versionKind    —— 按识别器（semver / date / digits）从文本里提取；
          ③ 两者都写           —— **先按标记截取、再按识别器提取**（页面片段里包着版本号时最稳）；
        都没写时返回 Missing（调用方自行回退到条目 version / 包内文件信息）。
    .OUTPUTS
        @{ Ok; Version; Error; Missing }
    #>
    param($Source, [string]$Text, [string]$Where = '来源文本')

    $result = @{ Ok = $false; Version = ''; Error = ''; Missing = $false }
    $versionKind = (Get-EntryString -Entry $Source -Key 'versionKind').Trim()
    $versionBetween = @(Get-EntryArray -Entry $Source -Key 'versionBetween')
    if (-not $versionKind -and $versionBetween.Count -eq 0) { $result.Missing = $true; return $result }

    $value = ''
    if ($null -ne $Text) { $value = [string]$Text }

    if ($versionBetween.Count -gt 0) {
        $between = Get-VersionBetween -Spec $versionBetween -Text $value
        if (-not $between.Ok) {
            $result.Error = ('versionBetween {0} 没有匹配到内容' -f ($versionBetween -join ' '))
            return $result
        }
        $value = [string]$between.Value
    }
    if ($versionKind) {
        $found = Get-VersionValue -Text $value -Kind $versionKind
        if (-not $found) {
            $result.Error = ('versionKind {0} 没有匹配到版本号' -f $versionKind)
            return $result
        }
        $value = [string]$found
    }

    $result.Ok = $true
    $result.Version = Get-NormalizedVersionString -Value $value
    return $result
}
