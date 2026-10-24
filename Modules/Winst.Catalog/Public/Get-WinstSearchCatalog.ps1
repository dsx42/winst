#Requires -Version 5.1

function Get-WinstSearchCatalog {
    <#
    .SYNOPSIS
        按关键字搜索全部软件源，结果按 id 合并成行（同 id 的多个来源列在同一行）。
    .DESCRIPTION
        匹配范围：id / 名称 / 说明的**子串**（不区分大小写）；关键字为空时返回全部软件。
        每行含各来源与其版本，供「列出软件源和软件版本」使用。
    .OUTPUTS
        @( [ordered]@{ Id; Name; Description; Sources = @( @{ Source; Version; Ok; Error; Plan } ) } )
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string]$Keyword = ''
    )

    $keywordText = ''
    if ($null -ne $Keyword) { $keywordText = ([string]$Keyword).Trim() }

    # 搜索结果按关键字缓存：搜索 / 安装命令会对同一关键字反复调用（每个 id 一次全量扫描）；
    # 软件清单变动后由 Reset-WinstCatalogCache 移除条目
    $cache = Get-WinstState -Name WinstSearchCatalogCache
    if ($null -eq $cache) {
        $cache = New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase)
        $null = Set-WinstState -Name WinstSearchCatalogCache -Value $cache
    }
    if ($cache.ContainsKey($keywordText)) {
        return @($cache[$keywordText])
    }

    $groups = New-WinstOrdinalDictionary
    foreach ($item in @(Get-WinstAllResolvedApps -Context $Context)) {
        $app = $item['App']
        $id = Get-EntryString -Entry $app -Key 'id'
        if (-not $id) { continue }

        if ($keywordText) {
            $name = Get-EntryString -Entry $app -Key 'name'
            $description = Get-EntryString -Entry $app -Key 'description'
            $hit = $id.IndexOf($keywordText, [StringComparison]::OrdinalIgnoreCase) -ge 0
            if (-not $hit -and $name) { $hit = $name.IndexOf($keywordText, [StringComparison]::OrdinalIgnoreCase) -ge 0 }
            if (-not $hit -and $description) { $hit = $description.IndexOf($keywordText, [StringComparison]::OrdinalIgnoreCase) -ge 0 }
            if (-not $hit) { continue }
        }

        if (-not $groups.Contains($id)) {
            $groups[$id] = [ordered]@{
                Id          = $id
                Name        = (Get-EntryString -Entry $app -Key 'name')
                Description = (Get-EntryString -Entry $app -Key 'description')
                Sources     = @()
            }
        }
        $row = $groups[$id]
        if (-not $row['Name']) { $row['Name'] = (Get-EntryString -Entry $app -Key 'name') }
        if (-not $row['Description']) { $row['Description'] = (Get-EntryString -Entry $app -Key 'description') }
        $row['Sources'] += @{
            Source  = [string]$item['Source']
            Version = (Get-EntryString -Entry $app -Key 'version')
            Ok      = (Get-EntryBool -Entry $app -Key 'ok')
            Error   = (Get-EntryString -Entry $app -Key 'error')
            Plan    = $app
        }
    }

    $rows = New-Object 'System.Collections.Generic.List[object]'
    foreach ($id in @($groups.Keys | Sort-Object)) {
        $row = $groups[$id]
        $row['Group'] = Get-WinstRowGroup -Row $row
        $rows.Add($row)
    }
    $finalRows = @($rows.ToArray())
    # 写回缓存前要重新确认容器：上面的 Get-WinstAllResolvedApps 可能触发软件源自动刷新
    # （Update-ManifestSource → Write-ManifestMeta），那会把缓存置空，
    # 于是这里的赋值变成「向 Null 数组建立索引」。
    if (-not (Test-WinstState -Name WinstSearchCatalogCache)) {
        $null = Set-WinstState -Name WinstSearchCatalogCache -Value (New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase))
    }
    # 空结果也缓存：搜不到的关键字同样会被反复查询（安装流程里每个 id 一次）
    (Get-WinstState -Name WinstSearchCatalogCache)[$keywordText] = $finalRows
    return $finalRows
}
