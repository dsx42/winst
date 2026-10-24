#Requires -Version 5.1

function Get-WinstManifestHashFromPlan {
    <#
    .SYNOPSIS
        取某个包文件「按软件源声明算法」的摘要（写回缓存索引 manifestHashes 用）：返回 @{ Algorithm; Hash }。
    .DESCRIPTION
        只有期望算法不是 sha256 时才需要单独记录（sha256 由 hashes 字段承担）；
        计划里没有（未声明校验 / 旧索引 / 字段缺失）时返回空，调用方跳过即可。
    #>
    param($Plan)

    $result = @{ Algorithm = ''; Hash = '' }
    if (-not $Plan) { return $result }
    if (-not $Plan.Contains('ExpectedAlgorithm')) { return $result }

    $algorithm = [string]$Plan['ExpectedAlgorithm']
    if (-not $algorithm -or $algorithm -eq 'SHA256') { return $result }

    $result.Algorithm = $algorithm
    if ($Plan.Contains('ManifestHash')) { $result.Hash = [string]$Plan['ManifestHash'] }
    return $result
}
