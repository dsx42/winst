#Requires -Version 5.1

function Get-WinstSearchRowView {
    <#
    .SYNOPSIS
        为搜索结果生成 CLI 与菜单共用的展示事实。
    #>
    param($Row, [hashtable]$State = $null, [hashtable]$Context, $CacheIndex = $null)

    $ledger = $null
    $version = ''
    $dir = ''
    if ($State) {
        $ledger = Get-WinstInstalledApp -State $State -Id ([string]$Row['Id'])
        if ($ledger) {
            $version = Get-EntryString -Entry $ledger -Key 'version'
            $dir = Get-EntryString -Entry $ledger -Key 'installDir'
        }
    }
    return @{
        CompanionVersionLines = @(Get-WinstCompanionVersionLines -Context $Context -Id ([string]$Row['Id']) -Row $Row -Ledger $ledger -CacheIndex $CacheIndex)
        Id = [string]$Row['Id']; DisplayName = [string]$Row['Name']; InstalledVersion = $version
        InstalledDir = $dir; UpgradeHint = (Get-WinstUpgradeHint -Row $Row -InstalledVersion $version)
        Type = (Get-WinstRowType -Row $Row); SourceText = (Get-WinstRowSourceText -Row $Row)
        Description = [string]$Row['Description']
    }
}
