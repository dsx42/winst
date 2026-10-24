#Requires -Version 5.1

function Get-JsonKeySegments {
    <#
    .SYNOPSIS
        把点分字段名拆成段；'…' 引号里的段按字面量取（可含点），如
        metadata.files.'opencode-windows-x64.zip'.url → metadata / files / opencode-windows-x64.zip / url。
    .DESCRIPTION
        JSON 对象的键本身可能带点（按文件名取值的表，如 opencode 更新接口的 metadata.files），点分写法
        无法表达——用单引号把这一段包起来即可。未闭合引号时剩余部分整体当一段（取不到由调用方报错）。
    #>
    param([string]$Key)

    $segments = @()
    $rest = [string]$Key
    while ($rest.Length -gt 0) {
        if ($rest[0] -eq "'") {
            $end = $rest.IndexOf("'", 1)
            if ($end -lt 0) {
                $segments += $rest.Substring(1)
                break
            }
            $segments += $rest.Substring(1, $end - 1)
            $rest = $rest.Substring($end + 1)
            if ($rest.StartsWith('.')) { $rest = $rest.Substring(1) }
            continue
        }
        $dot = $rest.IndexOf('.')
        if ($dot -lt 0) {
            $segments += $rest
            break
        }
        $segments += $rest.Substring(0, $dot)
        $rest = $rest.Substring($dot + 1)
    }
    return @($segments)
}
