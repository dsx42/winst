#Requires -Version 5.1

function Get-WinstDisplayIds {
    <#
    .SYNOPSIS
        从一组列表项 / 台账键里收集要去重的软件 id（供 Update-WinstDisplaySources 按需刷新）。
    .DESCRIPTION
        「先确定这次要展示哪些软件 → 只刷新这些软件的版本信息」是各列表页的共同前提，
        但每个页面拿到 id 的来源不同：已下载包 / 软件列表来自刚构建的概览项，已装软件来自
        安装台账，搜索来自命中行，bundle / list 来自清单条目。

        这段「遍历 + 跳过空值 + 去重」集中在这里，避免各页面各自实现时漏判 `$null`，
        让空 id 进到刷新集合里。
    .OUTPUTS
        [string[]] 去重后的 id（保持首次出现顺序）
    #>
    param(
        # 列表项（hashtable，取 Id 键）或其他「带 id 的对象」
        [AllowEmptyCollection()]$Items = @(),
        # 直接给 id 字符串时用这个（与 -Items 二选一）
        [AllowEmptyCollection()][string[]]$Ids = @(),
        # 从对象的哪个属性 / 键取 id
        [string]$IdKey = 'Id'
    )

    $collected = New-Object 'System.Collections.Generic.List[string]'
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)

    $add = {
        param([string]$Candidate)
        if (-not $Candidate) { return }
        if ($seen.Add($Candidate)) { $collected.Add($Candidate) }
    }

    foreach ($raw in @($Ids)) {
        & $add ([string]$raw)
    }
    foreach ($item in @($Items)) {
        if ($null -eq $item) { continue }
        $value = $null
        if ($item -is [System.Collections.IDictionary]) {
            if ($item.Contains($IdKey)) { $value = $item[$IdKey] }
        } else {
            $prop = $item.PSObject.Properties[$IdKey]
            if ($prop) { $value = $prop.Value }
        }
        & $add ([string]$value)
    }

    return $collected.ToArray()
}
