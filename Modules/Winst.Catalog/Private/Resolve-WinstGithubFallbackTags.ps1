#Requires -Version 5.1

function Resolve-WinstGithubFallbackTags {
    <#
    .SYNOPSIS
        生成「最新发布里没有需要的文件时」要逐个回退尝试的发布 tag 列表（从新到旧）。
    .DESCRIPTION
        GitHub 上常见的一种情况是：**release 已经建好、资产还在上传**。这时 `releases/latest` 指向的
        就是那个还不完整的发布，按它解析必然失败（「里还没有符合 xxx 的安装包」）。用户能用的其实是
        上一次发布的文件，因此退回「上一个有该文件的发布」。

        **排序按版本号，不按页面顺序**：列表页是 GitHub 的展示顺序（temurin21 页面上 `21.0.9+10` 排在
        `21.0.13+9` 前面），按页面顺序回退会取到错误的「次新版本」。这里用 `Get-WinstVersionSortKey`
        生成可比较的键后从高到低排。

        分三段返回，前面的先用：

        ① 能解析出版本号、且版本**严格低于** `-ChosenTag` 的发布（真正的「次新版本」）
        ② 能解析出版本号、但版本不低于 `ChosenTag` 的（候选里出现更新的发布时不至于被完全跳过）
        ③ 解析不出版本号的（`jdk25u-2026-02-02-15-22-beta` 这类 nightly，只能按页面顺序兜底排在最后）

        声明了 `-ReleaseTagPrefix` 时只留同前缀的条目（同一仓库按产品线分开发布）。
    .OUTPUTS
        [string[]]：候选 tag（不含 `-ChosenTag` 本身，已去重）；取不到发布列表时返回空数组
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Repo,
        [string]$ChosenTag = '',
        $Releases = @(),
        [string]$ReleaseTagPrefix = ''
    )

    # 注意变量名不能取 $releases：PowerShell 变量名不区分大小写，会与参数 $Releases 撞成同一个变量，
    # 一句 `$releases = @()` 就把传进来的列表清空了。
    $allTags = New-Object 'System.Collections.Generic.List[string]'
    foreach ($item in @($Releases)) {
        $tag = [string]$item['Tag']
        if ($tag -and -not $allTags.Contains($tag)) { $allTags.Add($tag) }
    }
    # 调用方通常已经把列表页读好了；为空时（如只走了 releases/latest 快捷路径）现读一次
    if ($allTags.Count -eq 0) {
        foreach ($item in @(Get-GitHubReleaseListTags -Context $Context -Repo $Repo)) {
            $tag = [string]$item['Tag']
            if ($tag -and -not $allTags.Contains($tag)) { $allTags.Add($tag) }
        }
    }
    if ($allTags.Count -eq 0) { return @() }

    # 声明了前缀时只留同前缀的发布（同一仓库按产品线分开发布）
    $pool = @()
    $sequence = 0
    foreach ($tag in $allTags.ToArray()) {
        if ($ChosenTag -and $tag -eq $ChosenTag) { continue }
        if ($ReleaseTagPrefix -and -not $tag.StartsWith($ReleaseTagPrefix, [StringComparison]::OrdinalIgnoreCase)) { continue }
        $sequence++
        $pool += [ordered]@{
            Tag      = $tag
            SortKey  = (Get-WinstVersionSortKey -Version $tag)
            Sequence = $sequence
        }
    }
    if ($pool.Count -eq 0) { return @() }

    $chosenKey = Get-WinstVersionSortKey -Version $ChosenTag

    # 按版本从高到低排（版本键相同则保持页面顺序）
    $sorted = @($pool | Sort-Object -Property @{ Expression = { [string]$_['SortKey'] }; Descending = $true },
        @{ Expression = { [int]$_['Sequence'] }; Descending = $false })

    $older = @()
    $others = @()
    $unversioned = @()
    foreach ($item in $sorted) {
        $sortKey = [string]$item['SortKey']
        $tag = [string]$item['Tag']
        if (-not $sortKey) { $unversioned += $tag; continue }
        if ($chosenKey -and [string]::CompareOrdinal($sortKey, $chosenKey) -ge 0) { $others += $tag; continue }
        $older += $tag
    }

    return @(@($older) + @($others) + @($unversioned))
}
