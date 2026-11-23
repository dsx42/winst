#Requires -Version 5.1

function Get-WinstPackItemList {
    <#
    .SYNOPSIS
        生成收包和套件安装清单共用的顺序，先列引擎和 winst，再按输入顺序展开各软件的传递依赖。
    .OUTPUTS
        @{ Plan; Errors }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][hashtable]$Lookup,
        $Items
    )

    $required = @((Get-WinstExtractEngineId), (Get-WinstDownloadEngineId), 'winst')
    $roots = New-WinstOrdinalDictionary
    $order = New-WinstOrdinalDictionary
    foreach ($id in $required) {
        $roots[$id] = $null
        $order[$id] = $true
    }
    foreach ($item in $Items) { $roots[[string]$item['Id']] = $item }

    $errors = @()
    foreach ($id in $roots.Keys) {
        $selected = Get-EntryValue -Entry $roots[$id] -Key 'PlanEntry'
        $resolved = Resolve-WinstDependencyOrder -Context $Context -Id $id -Plan (Get-EntryValue -Entry $selected -Key 'Plan')
        if (-not $resolved.Ok) { $errors += ('{0}: {1}' -f $id, $resolved.Error) }
        foreach ($dep in @($resolved.Missing) + @($resolved.Order)) { $order[[string]$dep['Id']] = $true }
        $order[$id] = $true
    }

    $plan = @(foreach ($id in $order.Keys) {
        if ($roots[$id]) { $roots[$id] }
        else { New-WinstListItem -Context $Context -Lookup $Lookup -Id $id }
    })
    return @{ Plan = $plan; Errors = $errors }
}
