#Requires -Version 5.1

function Get-WinstPackageVersionRule {
    <#
    .SYNOPSIS
        提取决定缓存包版本的包内识别规则与有序改写规则。
    #>
    param($Plan)

    return [ordered]@{
        packageVersion       = Get-EntryValue -Entry $Plan -Key 'packageVersion'
        sourceVersionRewrite = @(Get-EntryArray -Entry $Plan -Key 'sourceVersionRewrite')
    }
}
