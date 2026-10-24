#Requires -Version 5.1

function Get-SourceFileVersion {
    <#
    .SYNOPSIS
        取「这个文件」用于展开地址模板的版本号：files[] 可选声明 versionRewrite，只作用于该文件。
    .DESCRIPTION
        写法归一在清单里按作用对象分三处：source.versionRewrite 管源侧解析出的版本、
        detect.versionRewrite 管本机检测出的版本，两者都不影响 {version} 展开；而附加文件
        有时要用「另一个写法」的版本号拼地址（如 KeePass 主包是 2.61.1、
        语言包却是 KeePass-2.61-Chinese_Traditional.zip），此时在该文件上声明 versionRewrite，
        改写结果只用于这个文件的 url / file 规则展开。
    .OUTPUTS
        @{ Ok; Version; Error }
    #>
    param($Item, [string]$Version)

    $result = @{ Ok = $true; Version = ''; Error = '' }
    if ($null -ne $Version) { $result.Version = [string]$Version }
    if ($null -eq $Item) { return $result }

    $spec = Get-EntryValue -Entry $Item -Key 'versionRewrite' -Default $null
    if ($null -eq $spec) { return $result }

    $rules = New-WinstVersionRewriteRules -Spec $spec
    if (-not $rules.Ok) {
        $result.Ok = $false
        $result.Error = ('这个附加文件的 versionRewrite 有误（只作用于该文件的地址模板展开）: {0}' -f $rules.Error)
        return $result
    }
    $result.Version = Get-WinstRewrittenVersion -Version $result.Version -Rules $rules.Rules
    return $result
}
