#Requires -Version 5.1

function Read-WinstList {
    <#
    .SYNOPSIS
        读取行式清单文件。
    .DESCRIPTION
        空行忽略；`#` 开头为注释（原样保留、保存时写回文件开头）；其余每行 `id` 或 `id==版本`。
        同一 id 只保留第一次出现；无法识别的行计入 BadLines（保存时会丢弃，调用方需提示）。
        文件不存在时返回成功 + 空清单（便于「新建」场景）。
    .OUTPUTS
        @{ Ok; Error; Exists; Entries = @( @{ Id; Version; Raw } ); CommentLines; BadLines }
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    $result = @{ Ok = $false; Error = ''; Exists = $false; Entries = @(); CommentLines = @(); BadLines = @() }

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { $result.Ok = $true; return $result }
    $result.Exists = $true

    $lines = @()
    try { $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8) }
    catch {
        $result.Error = ('读取清单失败: {0}' -f $_.Exception.Message)
        return $result
    }

    $seen = New-WinstOrdinalDictionary
    # 逐行数组追加是 O(n²)：几千行的清单会明显变慢，统一改 List
    $entries = New-Object 'System.Collections.Generic.List[object]'
    $comments = New-Object 'System.Collections.Generic.List[string]'
    $bad = New-Object 'System.Collections.Generic.List[string]'
    foreach ($line in $lines) {
        $text = [string]$line
        $trimmed = $text.Trim()
        if (-not $trimmed) { continue }
        if ($trimmed.StartsWith('#')) { $comments.Add($trimmed); continue }

        $id = $trimmed
        $version = ''
        $pos = $trimmed.IndexOf('==')
        if ($pos -ge 0) {
            $id = $trimmed.Substring(0, $pos).Trim()
            $version = $trimmed.Substring($pos + 2).Trim()
        }
        # id 会进入台账 / 依赖解析 / 缓存目录：单层名字、长度与保留设备名在这里就挡住，坏行计入 BadLines
        if (-not $id -or -not (Test-WinstSafePathSegment -Name $id)) { $bad.Add($trimmed); continue }
        if ($seen.Contains($id)) { continue }
        $seen[$id] = $true
        $entries.Add([ordered]@{ Id = $id; Version = $version; Raw = $trimmed })
    }

    $result.Entries = @($entries.ToArray())
    $result.CommentLines = @($comments.ToArray())
    $result.BadLines = @($bad.ToArray())
    $result.Ok = $true
    return $result
}
