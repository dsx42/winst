#Requires -Version 5.1

function Write-WinstPlanCopyStage {
    <#
    .SYNOPSIS
        ③ 复制 / 改名段。
    #>
    param($Plan, [hashtable]$View)

    $copyLines = @()
    foreach ($rule in @(Get-EntryArray -Entry $Plan -Key 'postInstallCopy')) {
        $action = '复制一份'
        if (Get-EntryBool -Entry $rule -Key 'move') { $action = '改名' }
        $fromText = Expand-PlanPlaceholders -Value (Get-EntryString -Entry $rule -Key 'from') -InstallDir $View.InstallDir -InstallRoot $View.InstallRoot
        $toText = Expand-PlanPlaceholders -Value (Get-EntryString -Entry $rule -Key 'to') -InstallDir $View.InstallDir -InstallRoot $View.InstallRoot
        if ($View.InstallDir -and $fromText -and -not [IO.Path]::IsPathRooted($fromText)) { $fromText = Join-Path $View.InstallDir $fromText }
        if ($View.InstallDir -and $toText -and -not [IO.Path]::IsPathRooted($toText)) { $toText = Join-Path $View.InstallDir $toText }
        $copyLines += ('{0} → {1}（{2}）' -f $fromText, $toText, $action)
    }
    Write-ResolvedStage -Marker '③' -Label '复制' -Lines $copyLines
}
