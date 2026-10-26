#Requires -Version 5.1

function Test-WinstOldVersionsEqual {
    <#
    .SYNOPSIS
        比较两组「旧版本登记」是否等价（按版本号 + 卸载键，不区分大小写）。
    .DESCRIPTION
        两侧的键名大小写不同（检测结果用小写 `version` / `recordKey`，展示视图与台账用大写），
        这里两种都认，避免同一份数据因为键名写法不同被判成「有改动」并反复写盘。
    .OUTPUTS
        [bool]
    #>
    param($A = @(), $B = @())

    $left = @($A)
    $right = @($B)
    if ($left.Count -ne $right.Count) { return $false }
    for ($i = 0; $i -lt $left.Count; $i++) {
        $av = Get-EntryString -Entry $left[$i] -Key 'version'
        if (-not $av) { $av = Get-EntryString -Entry $left[$i] -Key 'Version' }
        $bv = Get-EntryString -Entry $right[$i] -Key 'version'
        if (-not $bv) { $bv = Get-EntryString -Entry $right[$i] -Key 'Version' }
        if ($av -ine $bv) { return $false }
        $ak = Get-EntryString -Entry $left[$i] -Key 'recordKey'
        if (-not $ak) { $ak = Get-EntryString -Entry $left[$i] -Key 'RecordKey' }
        $bk = Get-EntryString -Entry $right[$i] -Key 'recordKey'
        if (-not $bk) { $bk = Get-EntryString -Entry $right[$i] -Key 'RecordKey' }
        if ($ak -ine $bk) { return $false }
    }
    return $true
}
