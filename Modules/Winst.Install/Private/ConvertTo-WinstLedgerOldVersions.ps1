#Requires -Version 5.1

function ConvertTo-WinstLedgerOldVersions {
    # 检测结果和回读的台账都使用不区分大小写的字段，落盘时统一写台账字段名。
    param($OldVersions)

    foreach ($item in @($OldVersions)) {
        $version = Get-EntryString -Entry $item -Key 'version'
        if (-not $version) { continue }
        [ordered]@{
            version   = $version
            detail    = (Get-EntryString -Entry $item -Key 'detail')
            recordKey = (Get-EntryString -Entry $item -Key 'recordKey')
        }
    }
}
