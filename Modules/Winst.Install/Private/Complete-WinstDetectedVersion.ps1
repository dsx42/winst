#Requires -Version 5.1

function Complete-WinstDetectedVersion {
    <#
    .SYNOPSIS
        把各检测方式收集到的「命中版本」整理成「最新版本 + 旧版本列表」。
    .DESCRIPTION
        同一个软件可能同时存在多个版本（如 .NET Desktop Runtime 升级后，旧的
        `shared\Microsoft.WindowsDesktop.App\10.0.13` 与新装的 `10.0.14` 并存）。各检测方式只负责
        把每个命中实例记进 `Result.Versions`（单值检测方式直接写 `Result.Version`），这里统一：

        ① 按 `detect.versionRewrite` 归一每个版本的写法；
        ② 按版本号去重（同一版本可能由多条注册表记录 / 多个文件给出）；
        ③ 从高到低排序，`Version` 取最新那个；
        ④ 只有 `GroupKey` 与最新版本**相同**的条目才算旧版本 `OldVersions`——
           不同产品（如 VC++ 2019 与 2022、x64 与 x86）可以并存，不能报成「旧版本」让用户卸掉。

        版本号一律按 `Compare-WinstVersion` 语义比较，不做字符串排序——字符串排序会把
        `10.0.12` 排在 `10.0.9` 之后。
    .OUTPUTS
        无（原地写 $Result 的 Ok / Found / Version / Detail / Versions / OldVersions）
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Result,
        $RewriteRules = @()
    )

    $rules = @($RewriteRules)
    $items = @()
    if ($null -ne $Result['Versions']) { $items = @($Result['Versions']) }
    if ($items.Count -eq 0 -and (Get-EntryString -Entry $Result -Key 'Version')) {
        $items = @([ordered]@{
            Version   = (Get-EntryString -Entry $Result -Key 'Version')
            Detail    = (Get-EntryString -Entry $Result -Key 'Detail')
            RecordKey = ''
            GroupKey  = ''
        })
    }

    $seen = New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase)
    $unique = New-Object 'System.Collections.Generic.List[object]'
    foreach ($item in $items) {
        $version = (Get-EntryString -Entry $item -Key 'Version').Trim()
        if (-not $version) { continue }
        if ($rules.Count -gt 0) {
            $rewritten = Get-WinstRewrittenVersion -Version $version -Rules $rules
            if ($rewritten) { $version = [string]$rewritten }
        }
        if (-not $version) { continue }
        # 去重按「版本号 + 产品键」：不同产品（VC++ 2019 / 2022）常常同号，不能互相吞掉
        $groupKey = (Get-EntryString -Entry $item -Key 'GroupKey').Trim()
        $dedupeKey = ('{0}|{1}' -f $version, $groupKey)
        if ($seen.ContainsKey($dedupeKey)) { continue }
        $seen[$dedupeKey] = $true
        $unique.Add([ordered]@{
            Version   = $version
            Detail    = (Get-EntryString -Entry $item -Key 'Detail')
            RecordKey = (Get-EntryString -Entry $item -Key 'RecordKey')
            GroupKey  = $groupKey
        })
    }

    # 从高到低插入排序（本机并存的版本个数很少，直接插入）
    $sorted = New-Object 'System.Collections.Generic.List[object]'
    foreach ($item in $unique.ToArray()) {
        $index = $sorted.Count
        for ($i = 0; $i -lt $sorted.Count; $i++) {
            $cmp = 0
            try { $cmp = Compare-WinstVersion -A ([string]$item['Version']) -B ([string]$sorted[$i]['Version']) } catch { $cmp = 0 }
            if ($cmp -gt 0) { $index = $i; break }
        }
        $sorted.Insert($index, $item)
    }

    $all = @($sorted.ToArray())
    $Result['Versions'] = $all
    $Result['OldVersions'] = @()
    if ($all.Count -eq 0) {
        $Result['Version'] = ''
        $Result['Ok'] = $false
        return
    }

    $newest = $all[0]
    $Result['Version'] = [string]$newest['Version']
    $Result['Ok'] = $true
    if ([string]$newest['Detail']) { $Result['Detail'] = [string]$newest['Detail'] }

    if ($all.Count -gt 1) {
        $newestGroup = [string]$newest['GroupKey']
        $newestVersion = [string]$newest['Version']
        $old = @()
        for ($i = 1; $i -lt $all.Count; $i++) {
            $candidateVersion = [string]$all[$i]['Version']
            # 只收严格低于最新版本的：同一版本可能由不同路径 / 不同记录重复给出，不能当成旧版本显示
            $cmp = 0
            try { $cmp = Compare-WinstVersion -A $candidateVersion -B $newestVersion } catch { $cmp = 0 }
            if ($cmp -ge 0) { continue }
            # 没有 GroupKey 时按「同一批检测结果」处理（单值来源只能确认是同一软件）
            $group = [string]$all[$i]['GroupKey']
            if ($newestGroup -and $group -and $group -ine $newestGroup) { continue }
            $old += $all[$i]
        }
        $Result['OldVersions'] = @($old)
    }
}
