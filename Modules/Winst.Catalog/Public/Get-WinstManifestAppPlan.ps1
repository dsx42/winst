#Requires -Version 5.1

function Get-WinstManifestAppPlan {
    <#
    .SYNOPSIS
        按 id 取得某软件的「全流程实际内容」（优先复用软件清单解析锁，未命中时实时解析）。
    .DESCRIPTION
        软件源之间互不覆盖，同一 id 可能命中多个来源：本函数返回全部命中（Matches），
        并可用 -PreferSource 指定优先来源；供引擎引导（固定用内置源）与用户交互选择来源共用。
    .OUTPUTS
        @{ Ok; Source; Plan; Error; Matches }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$PreferSource = '',
        [switch]$LiveResolve
    )

    $result = @{ Ok = $false; Source = ''; Plan = $null; Error = ''; Matches = @() }
    if (-not $Id) { $result.Error = '缺少软件 id'; return $result }

    $found = @(Get-ResolvedAppsById -Context $Context -Id $Id)
    $result.Matches = @($found)

    if (-not $LiveResolve -and $found.Count -gt 0) {
        $chosen = $null
        if ($PreferSource) {
            foreach ($m in $found) {
                if (([string]$m['Source'] -ieq $PreferSource) -and (Get-EntryBool -Entry $m['App'] -Key 'ok')) { $chosen = $m; break }
            }
        }
        if (-not $chosen) {
            foreach ($m in $found) {
                if (Get-EntryBool -Entry $m['App'] -Key 'ok') { $chosen = $m; break }
            }
        }
        if ($chosen) {
            $result.Ok = $true
            $result.Source = [string]$chosen['Source']
            $result.Plan = $chosen['App']
            return $result
        }

        $first = $found[0]
        $result.Source = [string]$first['Source']
        $result.Plan = $first['App']
        $result.Error = ('这个软件在软件源里的解析结果不可用：{0}' -f (Get-EntryString -Entry $first['App'] -Key 'error'))
        return $result
    }

    # 实时解析（该来源还没刷新过 / 明确要求跳过解析锁）
    # -PreferSource 在这里同样生效：调用方（引擎引导、winst 自身安装）指定了来源时，
    # 该来源必须先试，否则按源列表顺序先命中的其它来源会覆盖它——内置源里没有对应版本时
    # 会以「仓库还没有发布任何版本」失败，即使被指定的来源完全可用。
    $lastError = ''
    $fallbackPlan = $null
    $fallbackSource = ''

    $orderedSources = @(Get-ManifestSourceList -Context $Context)
    if ($PreferSource) {
        $preferred = @()
        $others = @()
        foreach ($source in $orderedSources) {
            if ([string]$source['name'] -ieq $PreferSource) { $preferred += $source } else { $others += $source }
        }
        $orderedSources = @(@($preferred) + @($others))
    }

    foreach ($source in $orderedSources) {
        $sname = [string]$source['name']
        $bundle = Get-WinstSourceEntries -Context $Context -Source $source
        if ($bundle.Error) { $lastError = $bundle.Error; continue }

        foreach ($entry in @($bundle.Entries)) {
            if ((Get-EntryString -Entry $entry -Key 'id') -cne $Id) { continue }
            try {
                $resolve = Resolve-AppSource -Context $Context -Entry $entry
                # 必须带 -Context：按包内结构读版本要用引擎路径、远端新鲜度探测要用代理序列，
                # 少了它 versionFromPackage 条目会退化成「引擎不可用 + 取缓存索引版本」。
                $plan = New-ResolvedAppPlan -ManifestOrigin $sname -Entry $entry -Resolve $resolve -PkgDir $Context.PkgDir -Context $Context
            } catch {
                $lastError = $_.Exception.Message
                continue
            }
            if ($plan['ok']) {
                $result.Ok = $true
                $result.Source = $sname
                $result.Plan = $plan
                return $result
            }
            if ($null -eq $fallbackPlan) {
                $fallbackPlan = $plan
                $fallbackSource = $sname
            }
            $lastError = [string]$plan['error']
        }
    }

    if ($fallbackPlan) {
        $result.Source = $fallbackSource
        $result.Plan = $fallbackPlan
    }
    if (-not $lastError) { $lastError = ('软件源里没有找到「{0}」这个软件' -f $Id) }
    $result.Error = $lastError
    return $result
}
