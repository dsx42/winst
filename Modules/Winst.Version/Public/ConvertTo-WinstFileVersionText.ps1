#Requires -Version 5.1

function ConvertTo-WinstFileVersionText {
    <#
    .SYNOPSIS
        把文件版本信息里的字符串规范化：逗号 / 分号分隔的数字序列改写成点号，并去掉末尾多余的 `.0` 段。
    .DESCRIPTION
        版本资源里的 FILEVERSION 是「3,71,1,0」这种写法，个别程序（如 FileZilla）把这个写法直接
        粘进了 FileVersion 字符串。原样交给版本识别器时，含空白的整串会被判成「不是版本号」，
        再按「第一个像版本号的内容」兜底就只取到中间的 `71`（用户看到的「3, 71, 1, 0 → 71」）。
        这里先把分隔符统一成点号，再去掉 4 段版本末尾恒为 0 的那一段（`3.71.1.0` → `3.71.1`，
        与软件源里的 `3.71.1` 同一写法）；版本比较本来就会把缺段按 0 补齐，因此这一步不改变比较结果，
        只让展示与台账里的写法与上游一致。
    #>
    param([string]$Text)

    if ($null -eq $Text) { return '' }
    $value = ([string]$Text).Trim()
    if (-not $value) { return '' }
    if ($value -match '^[vV]?\d+(\s*[,;]\s*\d+)+$') {
        $value = ($value -replace '\s*[,;]\s*', '.')
    }
    # 只处理「纯点分数字」：带构建号 / 说明文字的版本串（10.0.22621.1 (WinBuild.160101.0800)）保持原样
    if ($value -match '^\d+(\.\d+)+$') {
        $parts = @($value.Split('.'))
        while ($parts.Count -gt 3 -and $parts[$parts.Count - 1] -eq '0') {
            $parts = @($parts[0..($parts.Count - 2)])
        }
        $value = ($parts -join '.')
    }
    return $value
}
