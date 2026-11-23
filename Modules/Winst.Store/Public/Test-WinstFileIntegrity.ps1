#Requires -Version 5.1

function Test-WinstFileIntegrity {
    <#
    .SYNOPSIS
        校验已下载的安装包。
    .DESCRIPTION
        比对算法由**期望摘要的长度**决定（32 / 40 / 64 / 128 位十六进制 → MD5 / SHA1 / SHA256 / SHA512）——
        Maven 这类站点只提供 .sha512，写死用 sha256 计算实际摘要必然对不上。
    .OUTPUTS
        @{ Ok; Error; Network; Algorithm; ActualHash; ExpectedHash; IndexHash;
           ChecksumHashFile; ChecksumHashFrom }
        Algorithm  = 实际比对用的算法（MD5 / SHA1 / SHA256 / SHA512，供缓存索引按算法记录摘要）；
        ActualHash = 按期望算法算出的实际摘要；IndexHash = 该文件的 sha256（缓存索引统一存 sha256；期望算法就是 sha256 时与 ActualHash 相同）。
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$FilePath,
        $FileDecl
    )

    $result = @{
        Ok = $true; Error = ''; Network = $false; Algorithm = ''; ActualHash = ''
        ExpectedHash = ''; IndexHash = ''
        ChecksumHashFile = ''; ChecksumHashFrom = ''
    }

    $expected = Get-WinstExpectedHash -Context $Context -FileName (Split-Path -Leaf $FilePath) -FileDecl $FileDecl -IgnoreCachedHash
    if (-not $expected.Ok) {
        $result.Ok = $false
        $result.Error = $expected.Error
        $result.Network = [bool]$expected.Network
        return $result
    }
    if ($expected.Skipped) {
        $result.IndexHash = Get-WinstFileHash -Path $FilePath
        if (-not $result.IndexHash) {
            $result.Ok = $false
            $result.Error = ('计算文件校验值失败：{0}' -f $FilePath)
        }
        return $result
    }

    $result.ExpectedHash = [string]$expected.Hash
    $result.ChecksumHashFile = [string]$expected.HashFile
    $result.ChecksumHashFrom = [string]$expected.HashFrom

    $algorithm = $expected.Algorithm
    $result.Algorithm = $algorithm

    $indexHash = ''
    try {
        $actual = (Get-WinstFileHash -Path $FilePath -Algorithm $algorithm -IndexHash ([ref]$indexHash))
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
        $result.Error = ('安装包校验不通过（{0}：期望 {1}，实际 {2}）' -f $expected.Label, ([string]$expected.Hash).ToLowerInvariant(), ([string]$actual).ToLowerInvariant())
        return $result
    }

    $result.IndexHash = ([string]$indexHash).ToLowerInvariant()
    return $result
}
