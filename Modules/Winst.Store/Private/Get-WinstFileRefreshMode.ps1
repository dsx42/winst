#Requires -Version 5.1

function Get-WinstFileRefreshMode {
    <#
    .SYNOPSIS
        取某个文件条目的新鲜度档位。
    .OUTPUTS
        @{ Mode; MaxAgeHours; Raw; Invalid }
    .DESCRIPTION
        Mode 取值 auto / always / ifMissing / check / ttl（大小写、`-` 与 `_` 不敏感）；
        写法无法识别时按 auto 处理并把原始写法放进 Raw、Invalid 置真，调用方在 --verbose 提示。
        MaxAgeHours 取 files[].maxAgeHours，非正数 / 非法值回退 168（7 天）。
    #>
    param($FileDecl)

    $result = @{ Mode = 'auto'; MaxAgeHours = 168; Raw = ''; Invalid = $false }
    $raw = ''
    if ($null -ne $FileDecl) { $raw = (Get-EntryString -Entry $FileDecl -Key 'refresh').Trim() }
    if ($raw) {
        $result.Raw = $raw
        $normalized = $raw.ToLowerInvariant().Replace('-', '').Replace('_', '').Replace(' ', '')
        switch ($normalized) {
            'auto' { $result.Mode = 'auto' }
            'always' { $result.Mode = 'always' }
            'ifmissing' { $result.Mode = 'ifMissing' }
            'check' { $result.Mode = 'check' }
            'ttl' { $result.Mode = 'ttl' }
            default { $result.Mode = 'auto'; $result.Invalid = $true }
        }
    }

    $maxAge = Get-EntryValue -Entry $FileDecl -Key 'maxAgeHours' -Default $null
    if ($null -ne $maxAge) {
        $hours = 0
        if ([int]::TryParse([string]$maxAge, [ref]$hours) -and $hours -gt 0) { $result.MaxAgeHours = $hours }
    }
    return $result
}
