#Requires -Version 5.1

function Get-VersionKindPattern {
    <#
    .SYNOPSIS
        返回版本识别器对应的正则（命名组 v）；不认识的关键字返回空串。
    .DESCRIPTION
        semver：1.2 / 1.2.3 / 1.2.3.4（可带 v 前缀，如 v24.9.0）
        date  ：2026-09-07 / 2026.09.07 / 20260907
        digits：连续数字（2 位以上），如 20326
    #>
    param([string]$Kind)

    $k = ''
    if ($Kind) { $k = ([string]$Kind).Trim().ToLowerInvariant() }
    switch ($k) {
        'semver' { return '(?<![0-9])(?:[vV])?(?<v>[0-9]+(?:\.[0-9]+){1,3})(?![0-9])' }
        'date'   { return '(?<![0-9])(?<v>[0-9]{4}[-.][0-9]{2}[-.][0-9]{2}|[0-9]{8})(?![0-9])' }
        'digits' { return '(?<![0-9])(?<v>[0-9]{2,})(?![0-9])' }
        default  { return '' }
    }
}
