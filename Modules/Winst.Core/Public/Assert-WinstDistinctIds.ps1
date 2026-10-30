#Requires -Version 5.1

function Assert-WinstDistinctIds {
    <#
    .SYNOPSIS
        id 保持 Ordinal 身份；拒绝仅大小写不同的身份共用 Windows 目录或 JSON 字典。
    #>
    param([string[]]$Ids = @())

    $seen = New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($id in @($Ids)) {
        if (-not $id) { continue }
        if ($seen.ContainsKey($id) -and [string]$seen[$id] -cne $id) {
            throw ('软件 id「{0}」与「{1}」仅大小写不同，不能共用 Windows 安装 / 缓存目录；请为其中一个选择不同的 id。' -f $seen[$id], $id)
        }
        $seen[$id] = $id
    }
}
