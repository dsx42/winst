#Requires -Version 5.1

function Test-WinstOldVersionsEqual {
    <#
    .SYNOPSIS
        比较两组「旧版本登记」是否等价（按版本号 + 卸载键，不区分大小写）。
    .DESCRIPTION
        台账字段为 version / recordKey，检测结果字段为 Version / RecordKey。
        传入区分大小写的字典时，优先读取非空的台账字段。
    .OUTPUTS
        [bool]
    #>
    param($A, $B)

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
