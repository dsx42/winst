#Requires -Version 5.1

function Get-WinstVersionRule {
    <#
    .SYNOPSIS
        校验清单来源的版本类型（versionKind）。
    .DESCRIPTION
        page / json / magnet 解析器共用这套判断与文案（与 Get-WinstVersionKindError 完全同文），
        统一到这里；新增识别器时只改 Get-WinstVersionPatterns。
    .OUTPUTS
        @{ Ok; Error }
    #>
    param($Source)

    $kind = (Get-EntryString -Entry $Source -Key 'versionKind').Trim()
    $kindError = Get-WinstVersionKindError -Kind $kind
    if ($kindError) {
        return @{ Ok = $false; Error = $kindError }
    }
    return @{ Ok = $true; Error = '' }
}
