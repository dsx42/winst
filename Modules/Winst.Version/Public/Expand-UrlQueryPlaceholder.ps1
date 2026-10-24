#Requires -Version 5.1

function Expand-UrlQueryPlaceholder {
    <#
    .SYNOPSIS
        把文本中的 {urlQuery:参数名} 占位符替换为「下载地址查询串里的对应参数值」。
    .DESCRIPTION
        典型用途：校验文件地址与主包地址共享同一个查询参数（如 Eclipse 的 download.php?file=… 与
        sums.php?file=…&type=sha512），hashFile 里写 {urlQuery:file} 即可随解析出的下载地址自动更新，
        清单里无需重复版本号。参数值按 URL 解码；同一参数出现多次取第一个；下载地址上没有该参数时
        原样保留占位符（与 {version} 无法替换的口径一致，后续按取不到校验文件处理）。
    #>
    param([string]$Text, [string]$Url)

    if ($null -eq $Text) { return '' }
    $text = [string]$Text
    if (-not [regex]::IsMatch($text, '\{urlQuery:[^}]+\}')) { return $text }

    $values = @{}
    if ($Url) {
        $query = [string]$Url
        $cut = $query.IndexOf('?')
        if ($cut -ge 0) {
            $query = $query.Substring($cut + 1)
            $cut = $query.IndexOf('#')
            if ($cut -ge 0) { $query = $query.Substring(0, $cut) }
            foreach ($pair in ($query -split '&')) {
                if (-not $pair) { continue }
                $eq = $pair.IndexOf('=')
                if ($eq -le 0) { continue }
                $name = $pair.Substring(0, $eq)
                if ($values.ContainsKey($name)) { continue }
                $value = $pair.Substring($eq + 1)
                try { $value = [Uri]::UnescapeDataString($value) } catch { }
                $values[$name] = $value
            }
        }
    }

    $result = $text
    foreach ($m in [regex]::Matches($text, '\{urlQuery:([^}]+)\}')) {
        $name = $m.Groups[1].Value
        if ($values.ContainsKey($name)) { $result = $result.Replace($m.Value, $values[$name]) }
    }
    return $result
}
