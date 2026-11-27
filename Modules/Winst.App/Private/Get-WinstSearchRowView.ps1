#Requires -Version 5.1

function Get-WinstSearchRowView {
    <#
    .SYNOPSIS
        为搜索结果生成 CLI 与菜单共用的展示事实。
    #>
    param($Row, [hashtable]$State, [hashtable]$Context, $CacheIndex)

    $ledger = Get-WinstInstalledApp -State $State -Id ([string]$Row['Id'])
    $version = Get-EntryString -Entry $ledger -Key 'version'
    return @{
        CompanionVersionLines = @(Get-WinstCompanionVersionLines -Context $Context -Id ([string]$Row['Id']) -Row $Row -Ledger $ledger -CacheIndex $CacheIndex)
        Id = [string]$Row['Id']; DisplayName = [string]$Row['Name']; InstalledVersion = $version
        InstalledDir = (Get-EntryString -Entry $ledger -Key 'installDir'); UpgradeHint = (Get-WinstUpgradeHint -Row $Row -InstalledVersion $version)
        Type = (Get-WinstRowType -Row $Row); SourceText = (Get-WinstRowSourceText -Row $Row)
        Description = [string]$Row['Description']
    }
}
