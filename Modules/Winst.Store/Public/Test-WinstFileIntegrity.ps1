#Requires -Version 5.1

function Test-WinstFileIntegrity {
    <#
    .SYNOPSIS
        校验已下载的安装包。
    .DESCRIPTION
        比对算法由**期望摘要的长度**决定（32 / 40 / 64 / 128 位十六进制 → MD5 / SHA1 / SHA256 / SHA512）——
        Maven 这类站点只提供 .sha512，写死用 sha256 计算实际摘要必然对不上。
    .OUTPUTS
        @{ Ok; Skipped; Error; Algorithm; ActualHash; ExpectedHash; Label; IndexHash;
           ChecksumHashFile; ChecksumHashFrom; ChecksumFingerprint }
        Algorithm  = 实际比对用的算法（MD5 / SHA1 / SHA256 / SHA512，供缓存索引按算法记录摘要）；
        ActualHash = 按期望算法算出的实际摘要；IndexHash = 该文件的 sha256（缓存索引统一存 sha256；期望算法就是 sha256 时与 ActualHash 相同）。
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$FilePath,
        $FileDecl,
        [string]$FileUrl = '',
        [string]$SourceVersion = ''
    )

    $result = @{
        Ok = $true; Skipped = $true; Error = ''; Algorithm = ''; ActualHash = ''
        ExpectedHash = ''; Label = 'sha256'; IndexHash = ''
        ChecksumHashFile = ''; ChecksumHashFrom = ''; ChecksumFingerprint = ''
    }

    $expected = Get-WinstExpectedHash -Context $Context -FileName (Split-Path -Leaf $FilePath) -FileDecl $FileDecl `
        -FileUrl $FileUrl -SourceVersion $SourceVersion
    if (-not $expected.Ok) {
        $result.Ok = $false
        $result.Skipped = $false
        $result.Error = $expected.Error
        return $result
    }
    if ($expected.Skipped) { return $result }

    $result.Skipped = $false
    $result.ExpectedHash = [string]$expected.Hash
    $result.Label = [string]$expected.Label
    $result.ChecksumHashFile = [string]$expected.HashFile
    $result.ChecksumHashFrom = [string]$expected.HashFrom
    $result.ChecksumFingerprint = [string]$expected.Fingerprint

    # 期望摘要认不出算法（如 re: 正则抓到其它长度的串）→ 只能按 sha256 比较
    $algorithm = Get-HashAlgorithmFromDigestLength -Length ([string]$expected.Hash).Length
    if (-not $algorithm) { $algorithm = 'SHA256' }
    $result.Algorithm = $algorithm

    $actual = ''
    try {
        $actual = (Get-WinstFileHash -Path $FilePath -Algorithm $algorithm)
    } catch {
        $actual = ''
    }
    if (-not $actual) {
        $result.Ok = $false
        $result.Error = ('计算文件校验值失败：{0}' -f $FilePath)
        return $result
    }
    $result.ActualHash = [string]$actual

    if ($actual -ine $expected.Hash) {
        $result.Ok = $false
        $result.Error = ('安装包校验不通过（{0}：期望 {1}，实际 {2}）' -f $result.Label, ([string]$expected.Hash).ToLowerInvariant(), ([string]$actual).ToLowerInvariant())
        return $result
    }

    # 缓存索引统一存 sha256：期望算法是 sha256 时直接复用它，否则再算一次（仅非 sha256 校验的包会多算一次）
    $indexHash = [string]$actual
    if ($algorithm -ne 'SHA256') {
        try { $indexHash = (Get-WinstFileHash -Path $FilePath -Algorithm SHA256) } catch { $indexHash = '' }
    }
    $result.IndexHash = ([string]$indexHash).ToLowerInvariant()
    return $result
}
