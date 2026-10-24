#Requires -Version 5.1

function Get-WinstPackItemList {
    <#
    .SYNOPSIS
        汇总「制作U盘安装包」要收集的软件：安装清单里的全部软件 + 它们的传递依赖 + 两个引擎包。
    .DESCRIPTION
        两个引擎（FluxDown-CLI / 7-Zip-CLI）不在用户清单里，但离线机器自动引导引擎时必须有本地包，
        因此**必须显式纳入收集范围**。
        清单里软件声明的 dependencies（含传递依赖）同样必须收集，否则离线机器安装时会缺依赖包。
    .OUTPUTS
        @( [ordered]@{ Item; Reason } )；Reason = 'list' | 'dependency' | 'engine'
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][hashtable]$Lookup,
        $Items
    )

    $result = @()
    $seen = New-WinstOrdinalDictionary

    foreach ($item in @($Items)) {
        $id = [string]$item['Id']
        if (-not $id) { continue }
        if ($seen.Contains($id)) { continue }
        $seen[$id] = $true
        $result += [ordered]@{ Item = $item; Reason = 'list' }
    }

    # 依赖闭包：安装清单里软件的传递依赖一并收集，保证离线机器装得起来
    foreach ($item in @($Items)) {
        $id = [string]$item['Id']
        if (-not $id) { continue }
        $resolvedDeps = Resolve-WinstDependencyOrder -Context $Context -Id $id
        if (-not $resolvedDeps.Ok) { continue }
        foreach ($one in @($resolvedDeps.Order)) {
            $depId = [string]$one['Id']
            if (-not $depId -or $seen.Contains($depId)) { continue }
            $seen[$depId] = $true
            $depItem = New-WinstListItem -Context $Context -Id $depId -Lookup $Lookup
            $result += [ordered]@{ Item = $depItem; Reason = 'dependency' }
        }
    }

    foreach ($engineId in @((Get-WinstDownloadEngineId), (Get-WinstExtractEngineId))) {
        $id = [string]$engineId
        if (-not $id -or $seen.Contains($id)) { continue }
        $seen[$id] = $true
        $item = New-WinstListItem -Context $Context -Id $id -Lookup $Lookup
        $result += [ordered]@{ Item = $item; Reason = 'engine' }
    }

    return @($result)
}
