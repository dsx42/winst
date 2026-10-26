#Requires -Version 5.1

function Test-WinstNameContainsVersion {
    <#
    .SYNOPSIS
        判断一段显示名里的版本号是否「指向同一个版本」（允许写法比版本号更粗）。
    .DESCRIPTION
        检测到的版本号常常比系统安装记录里写得更细：检测到 `10.0.13.50000`，
        而记录里的显示名只写 `... 10.0.13 (x64)`。反过来也可能出现 `10.0.13` 对 `10.0.13.50000`。

        因此不能简单做子串匹配（`10.0.13` 是 `10.0.130` 的子串，`10.0.1` 是 `10.0.13` 的子串），
        要按「数字段逐段相等」比较：名字里的版本号与给定版本号，前 N 段全部相同（N = 两者较短者），
        且段数差不超过 1 段（只允许省略末尾的构建号 / 尾零段）。

        `10.0.13` 对 `10.0.13.50000` → 相等且只差 1 段，命中；
        `10.0.13` 对 `10.0.14` → 第 3 段不同，不命中。
    .OUTPUTS
        [bool]
    #>
    param([string]$Text, [string]$Version)

    $name = ([string]$Text).Trim()
    $target = ([string]$Version).Trim()
    if (-not $name -or -not $target) { return $false }

    $targetSegments = @($target -split '[^\d]+' | Where-Object { $_ -ne '' })
    if ($targetSegments.Count -eq 0) { return $false }

    # 逐个取出名字里的数字串，看有没有一段连续数字与目标版本号段段相同
    $numbers = [regex]::Matches($name, '\d+(?:\.\d+)*')
    foreach ($m in $numbers) {
        $nameSegments = @($m.Value -split '\.')
        $count = [Math]::Min($nameSegments.Count, $targetSegments.Count)
        if ($count -lt 2) { continue }
        $same = $true
        for ($i = 0; $i -lt $count; $i++) {
            if ([string]$nameSegments[$i] -ne [string]$targetSegments[$i]) { $same = $false; break }
        }
        if (-not $same) { continue }
        # 只允许差一段（省略末尾构建号 / 尾零段），差更多就是把不同版本说成同一个
        $diff = [Math]::Abs($nameSegments.Count - $targetSegments.Count)
        if ($diff -le 1) { return $true }
    }
    return $false
}
