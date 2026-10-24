#Requires -Version 5.1

function Get-WinstPageFileHash {
    <#
    .SYNOPSIS
        从页面 HTML 里按文件名就近提取下载文件的摘要。
    .DESCRIPTION
        不少镜像站点把「文件名 + 摘要 + 下载链接」排在一行 / 一格（如 NTriver 的 Windows ISO 列表），
        摘要随每个版本更新，写死进清单反而会在上游换包后校验失败。这里按文件名在 HTML 里定位该条目，
        从文件名出现处向后的一小段里取摘要：先找 64 位十六进制串（SHA-256），没有再找 32 位的（MD5，
        如飞牛官网把 MD5 放在页面数据里）；找不到返回空串（调用方报错）。算法由调用方按摘要长度反推。
        侦察范围控制在 2000 字符内：既跨得过「文件名 → 摘要标签」之间的标记，也不会吃进下一个条目
        （相邻条目先出现的是它自己的文件名，不是长十六进制串）。
    #>
    param(
        [string]$Html,
        [string]$Url,
        [string]$Name = ''
    )

    if (-not $Html) { return '' }
    $fileName = ([string]$Name).Trim()
    if (-not $fileName) { $fileName = Get-FileNameFromUrl -Url $Url }
    if (-not $fileName) { return '' }

    $index = $Html.IndexOf($fileName, [StringComparison]::OrdinalIgnoreCase)
    if ($index -lt 0) { return '' }

    $start = $index + $fileName.Length
    $window = $Html.Substring($start, [Math]::Min(2000, $Html.Length - $start))
    # 先 64 位（SHA-256）后 32 位（MD5）：前后看断防止在更长的十六进制串中间误截
    $match = [regex]::Match($window, '(?i)(?<![0-9a-f])[0-9a-f]{64}(?![0-9a-f])')
    if (-not $match.Success) {
        $match = [regex]::Match($window, '(?i)(?<![0-9a-f])[0-9a-f]{32}(?![0-9a-f])')
    }
    if ($match.Success) { return $match.Value.ToLowerInvariant() }
    return ''
}
