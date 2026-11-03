#Requires -Version 5.1

function Write-WinstCompanionVersions {
    <#
    .SYNOPSIS
        只展示调用方已准备好的附件版本信息。
    #>
    param($Item)
    foreach ($line in @(Get-EntryArray -Entry $Item -Key 'CompanionVersionLines')) {
        if ($line) { Write-Host ('     {0}' -f $line) -ForegroundColor DarkGray }
    }
}