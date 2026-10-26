#Requires -Version 5.1

function New-WinstPlanCopyBlock {
    <#
    .SYNOPSIS
        ③ 复制 / 改名（postInstallCopy）→ 解析锁的 postInstallCopy 段。
    #>
    param($Entry, [string]$Version)

    $copyList = @()
    $validationRoot = Join-WinstPath ([IO.Path]::GetTempPath()) 'winst-manifest-path-check'
    foreach ($item in @(Get-EntryArray -Entry $Entry -Key 'postInstallCopy')) {
        $fromText = Expand-VersionPlaceholder -Text (Get-EntryString -Entry $item -Key 'from') -Version $Version
        $toText = Expand-VersionPlaceholder -Text (Get-EntryString -Entry $item -Key 'to') -Version $Version
        if (-not $fromText -or -not $toText) { continue }
        $fromCheck = Resolve-WinstSafeChildPattern -Root $validationRoot -Child $fromText -Label 'postInstallCopy.from'
        if (-not $fromCheck.Ok) { return @{ Items = @(); Error = [string]$fromCheck.Error } }
        $toCheck = Resolve-WinstSafeChildPath -Root $validationRoot -Child $toText -Label 'postInstallCopy.to'
        if (-not $toCheck.Ok) { return @{ Items = @(); Error = [string]$toCheck.Error } }
        $copyList += [ordered]@{
            from = $fromText
            to   = $toText
            move = (Get-EntryBool -Entry $item -Key 'move')
        }
    }
    return @{ Items = @($copyList); Error = '' }
}
