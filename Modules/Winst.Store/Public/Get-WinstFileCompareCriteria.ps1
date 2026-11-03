#Requires -Version 5.1

function Get-WinstFileCompareCriteria {
    <#
    .SYNOPSIS
        解析 files[].compare：把「用哪些判据判断远端文件是否变化」整理成有序判据集合。
    .DESCRIPTION
        缺省或 auto = 最后修改时间 + 文件大小（ETag 在不少主机上阶段性漂移，不作为默认判据）；
        也可以显式列出判据，用 `,` / `;` / `|` / 空白分隔，合法取值：
        etag、lastModified（别名 lm）、size、checksum（别名 hash / fingerprint）。
        大小写与 `-` / `_` 不敏感。无法识别的词收集到 Invalid，由调用方按 auto 处理并提示，
        与 files[].refresh 的容错口径一致（不静默丢弃，也不让整条清单解析失败）。
    .OUTPUTS
        @{ Criteria; Invalid; Raw; Text; IsDefault }
        Criteria = 归一后的判据（小写 etag / lastmodified / size / checksum）；
        Text     = 写回解析结果的规范文本（默认 `auto`，组合为 `lastModified,size` 这类写法）。
    #>
    param([string]$Text)

    $defaults = @('lastmodified', 'size')
    $result = @{ Criteria = @($defaults); Invalid = @(); Raw = ''; Text = 'auto'; IsDefault = $true }
    if ($null -ne $Text) { $result.Raw = [string]$Text }
    $raw = ([string]$result.Raw).Trim()
    if (-not $raw -or $raw -ieq 'auto') { return $result }

    $criteria = @()
    $invalid = @()
    foreach ($token in @([regex]::Split($raw, '[,;|\s]+'))) {
        $word = ([string]$token).Trim().ToLowerInvariant().Replace('-', '').Replace('_', '')
        if (-not $word) { continue }
        switch ($word) {
            'etag' { if ($criteria -notcontains 'etag') { $criteria += 'etag' } }
            'lastmodified' { if ($criteria -notcontains 'lastmodified') { $criteria += 'lastmodified' } }
            'lm' { if ($criteria -notcontains 'lastmodified') { $criteria += 'lastmodified' } }
            'size' { if ($criteria -notcontains 'size') { $criteria += 'size' } }
            'checksum' { if ($criteria -notcontains 'checksum') { $criteria += 'checksum' } }
            'hash' { if ($criteria -notcontains 'checksum') { $criteria += 'checksum' } }
            'fingerprint' { if ($criteria -notcontains 'checksum') { $criteria += 'checksum' } }
            default { if ($invalid -notcontains [string]$token) { $invalid += [string]$token } }
        }
    }

    if ($criteria.Count -eq 0) {
        $result.Invalid = @($invalid)
        return $result
    }

    $names = @()
    foreach ($one in $criteria) {
        if ($one -eq 'lastmodified') { $names += 'lastModified' } else { $names += $one }
    }
    $result.Criteria = @($criteria)
    $result.Invalid = @($invalid)
    $result.Text = ($names -join ',')
    $result.IsDefault = $false
    return $result
}
