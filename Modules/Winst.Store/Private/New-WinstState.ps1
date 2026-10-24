#Requires -Version 5.1

function New-WinstState {
    <#
    .SYNOPSIS
        新建空台账（schemaVersion 2；installed 为区分大小写的有序字典）。
    #>
    return @{
        SchemaVersion = (Get-WinstStateSchemaVersion)
        Installed     = (New-WinstOrdinalDictionary)
    }
}
