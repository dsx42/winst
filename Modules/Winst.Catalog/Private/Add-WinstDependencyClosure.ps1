#Requires -Version 5.1

function Add-WinstDependencyClosure {
    <#
    .SYNOPSIS
        Resolve-WinstDependencyOrder 的内部递归：后序遍历依赖，产出「依赖在前」的顺序。
    .DESCRIPTION
        Done / Visiting 两个集合分别承担「已完成」与「正在展开」，依赖成环时跳过，不会无限递归；
        软件源里不存在的依赖 id 记入 Missing（只记一次），由调用方提示后跳过。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$State,
        [Parameter(Mandatory = $true)][string]$Id,
        [int]$Level = 1
    )

    $map = $State['Deps']
    if (-not $map.Contains($Id)) {
        if (-not $State['MissingSeen'].Contains($Id)) {
            $State['MissingSeen'][$Id] = $true
            $State['Missing'] += @{ Id = $Id; Level = $Level; Via = [string]$State['Via'][$Id] }
        }
        return
    }
    if ($State['Done'].Contains($Id)) { return }
    if ($State['Visiting'].Contains($Id)) { return }
    $State['Visiting'][$Id] = $true

    foreach ($childId in @($map[$Id])) {
        if ($State['Done'].Contains($childId) -or $State['Visiting'].Contains($childId)) { continue }
        if (-not $State['Levels'].Contains($childId)) {
            $State['Levels'][$childId] = $Level + 1
            $State['Via'][$childId] = $Id
        }
        Add-WinstDependencyClosure -State $State -Id $childId -Level ($Level + 1)
    }

    $State['Visiting'].Remove($Id)
    $State['Done'][$Id] = $true
    $State['Order'] += $Id
    return
}
