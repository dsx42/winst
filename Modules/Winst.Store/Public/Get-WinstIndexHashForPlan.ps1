#Requires -Version 5.1

function Get-WinstIndexHashForPlan {
    <#
    .SYNOPSIS
        取某个包文件写回缓存索引 hashes 用的 sha256。
    .DESCRIPTION
        优先用计划里已有的 sha256（RecordedHash / IndexHash）；都没有而文件又在缓存里时，
        才现算一次（仅「软件源声明非 sha256 摘要 + 索引里还没有 sha256」这一种情况会走到），
        算出来交给调用方写回索引，下次运行就能直接命中、不重复计算。
    #>
    param([string]$FilePath, $Plan)

    foreach ($key in @('RecordedHash', 'IndexHash')) {
        if ($Plan -and $Plan.Contains($key)) {
            $value = [string]$Plan[$key]
            if ($value) { return $value.ToLowerInvariant() }
        }
    }

    if (-not $FilePath -or -not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { return '' }
    try { return ([string](Get-WinstFileHash -Path $FilePath -Algorithm SHA256)).ToLowerInvariant() } catch { return '' }
}
