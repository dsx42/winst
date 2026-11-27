#Requires -Version 5.1

function Get-WinstDependents {
    <#
    .SYNOPSIS
        反查依赖某个 id 的软件（直接 + 间接，含层级与经由哪个软件），只返回已安装的。
    .DESCRIPTION
        把依赖关系反转成「被依赖 → 依赖者」图后从 id 出发按层展开（同一软件只保留首次出现的链路）；
        用安装记录过滤，只列出真正装在本机上的依赖者。用于卸载前的提示，不做拦截。
    .OUTPUTS
        @{ Ok; Items = @( @{ Id; Name; Level; Via; ViaName } ) }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id
    )

    $result = @{ Ok = $false; Items = @() }
    $index = Get-WinstDependencyIndex -Context $Context

    $stateRead = Read-WinstState -InstallRoot $Context.InstallRoot
    if ($stateRead.Error -and -not $stateRead.Reset) {
        return $result
    }
    $state = $stateRead.State

    # 依赖索引已按软件去重，将每条依赖反向登记一次。
    $reverse = New-WinstOrdinalDictionary
    foreach ($appId in @($index['Deps'].Keys)) {
        foreach ($depId in @($index['Deps'][$appId])) {
            $depKey = [string]$depId
            if (-not $reverse.Contains($depKey)) {
                $reverse[$depKey] = New-Object 'System.Collections.Generic.List[string]'
            }
            $reverse[$depKey].Add([string]$appId)
        }
    }

    $levels = New-WinstOrdinalDictionary
    $via = New-WinstOrdinalDictionary
    $seen = New-WinstOrdinalDictionary
    $queue = New-Object 'System.Collections.Queue'
    $queue.Enqueue($Id)
    $seen[$Id] = $true
    $levels[$Id] = 0
    while ($queue.Count -gt 0) {
        $current = [string]$queue.Dequeue()
        if (-not $reverse.Contains($current)) { continue }
        foreach ($parentId in @($reverse[$current])) {
            if ($seen.Contains($parentId)) { continue }
            $seen[$parentId] = $true
            $levels[$parentId] = [int]$levels[$current] + 1
            $via[$parentId] = $current
            $queue.Enqueue($parentId)
        }
    }

    $items = New-Object 'System.Collections.Generic.List[object]'
    foreach ($key in @($seen.Keys)) {
        $otherId = [string]$key
        if ($otherId -ceq $Id) { continue }
        if (-not (Get-WinstInstalledApp -State $state -Id $otherId)) { continue }
        $otherName = $otherId
        if ($index['Rows'].Contains($otherId)) {
            $rowName = Get-EntryString -Entry $index['Rows'][$otherId] -Key 'Name'
            if ($rowName) { $otherName = $rowName }
        }
        $viaId = [string]$via[$otherId]
        $viaName = $viaId
        if ($viaId -and $index['Rows'].Contains($viaId)) {
            $viaRowName = Get-EntryString -Entry $index['Rows'][$viaId] -Key 'Name'
            if ($viaRowName) { $viaName = $viaRowName }
        }
        $items.Add(@{ Id = $otherId; Name = $otherName; Level = [int]$levels[$otherId]; Via = $viaId; ViaName = $viaName })
    }
    $result.Items = @($items.ToArray() | Sort-Object -Property @{ Expression = { [int]$_['Level'] } },
                                                               @{ Expression = { ([string]$_['Id']).ToLowerInvariant() } })
    $result.Ok = $true
    return $result
}
