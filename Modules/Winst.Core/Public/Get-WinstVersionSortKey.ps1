#Requires -Version 5.1

function Get-WinstVersionSortKey {
    <#
    .SYNOPSIS
        把版本号（或发布 tag）转成可排序的「定长数字段键」。
    .DESCRIPTION
        `Compare-WinstVersion` 是按语义比较（`1.2.3` = `1.2.3.0`、`-` 后缀表示预发布），
        但它是**成对比较**，拿来做排序要 O(n log n) 次比较、还要处理相等时的稳定性。
        这里生成一个可以直接做字符串比较的键：

        - 取开头的点分数字段（`jdk-25.0.4.1+1` → `25.0.4.1`），**忽略 `+build`**：
          JEP 223 里 `25+36` 是「feature 25 / build 36」，等价于 `25.0.0`；
          若不忽略，`25+36` 的 `36` 会被当成第 2 段，从而排在 `25.0.5` 之后。
        - 每段补零到 9 位、不足 5 段补零段：`25.0.4.1` →
          `000000025.000000000.000000004.000000001.000000000`，
          这样字符串比较就等于数值比较（`10.0.9` 不会排在 `10.0.12` 之后）。
        - 段数不足的在末尾补零段，保证 `1.2` 与 `1.2.0` 得到同样的前缀长度。

        取不到数字段的 tag（`nightly` 之类）返回空串，由调用方决定怎么排。
    .OUTPUTS
        [string] 排序键；完全取不到数字段时返回空串
    #>
    param([string]$Version)

    $text = ([string]$Version).Trim()
    if (-not $text) { return '' }

    # 去掉 +build（JEP 223 的 build 号，以及 SemVer 的构建元数据）
    $plus = $text.IndexOf('+')
    if ($plus -ge 0) { $text = $text.Substring(0, $plus) }

    # 取第一个「点分数字串」：跳过前缀（jdk- / v / cli-v 等）
    $m = [regex]::Match($text, '\d+(?:\.\d+)*')
    if (-not $m.Success) { return '' }

    $parts = @($m.Value -split '\.')
    $segments = New-Object 'System.Collections.Generic.List[string]'
    foreach ($part in $parts) {
        $digits = ([string]$part).TrimStart('0')
        if (-not $digits) { $digits = '0' }
        # 超长数字段截断到 9 位（版本号不会有这么大的段），避免定长格式被撑坏
        if ($digits.Length -gt 9) { $digits = $digits.Substring($digits.Length - 9) }
        $segments.Add($digits.PadLeft(9, '0'))
    }
    # 补齐到固定 5 段：让「1.2」与「1.2.0.0.0」比较结果一致
    while ($segments.Count -lt 5) { $segments.Add('000000000') }

    return ($segments.ToArray() -join '.')
}
