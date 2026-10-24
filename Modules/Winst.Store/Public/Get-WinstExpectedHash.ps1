#Requires -Version 5.1

function Get-WinstExpectedHash {
    <#
    .SYNOPSIS
        取某个文件「应该」有的 sha256：files[].hash 字面值，或 hashFile + hashFrom 从官方校验文件里取。
    .OUTPUTS
        @{ Ok; Hash; Label; Skipped; Error; HashFile; HashFrom; Fingerprint }
    .DESCRIPTION
        Hash 为空串表示该文件未声明校验（Skipped = $true）；Ok = $false 表示校验文件抓取 / 解析失败。
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$FileName,
        $FileDecl,
        [switch]$Offline,
        $CachedMeta = $null,
        [string]$FileUrl = '',
        [string]$SourceVersion = ''
    )

    $result = @{
        Ok = $true; Hash = ''; Label = 'sha256'; Skipped = $true; Error = ''
        HashFile = ''; HashFrom = ''; Fingerprint = ''
    }
    if ($null -eq $FileDecl) { return $result }

    $hash = (Get-EntryString -Entry $FileDecl -Key 'hash').Trim()
    $hashFile = (Get-EntryString -Entry $FileDecl -Key 'hashFile').Trim()
    if (-not $hash -and -not $hashFile) { return $result }

    if ($hash) {
        $result.Hash = $hash
        $result.Skipped = $false
        return $result
    }

    $hashFrom = (Get-EntryString -Entry $FileDecl -Key 'hashFrom').Trim()
    if (-not $hashFrom) { $hashFrom = 'sha256sums' }
    $result.Label = $hashFrom
    $result.HashFile = $hashFile
    $result.HashFrom = $hashFrom
    $result.Fingerprint = Get-WinstChecksumDeclarationFingerprint -FileName $FileName -FileDecl $FileDecl `
        -FileUrl $FileUrl -SourceVersion $SourceVersion

    if ($Offline) {
        $cachedHash = ''
        $cachedFingerprint = ''
        $cachedHashFile = ''
        $cachedHashFrom = ''
        if ($CachedMeta) {
            $cachedHash = ([string]$CachedMeta.ExpectedHash).Trim()
            $cachedFingerprint = ([string]$CachedMeta.ChecksumFingerprint).Trim()
            $cachedHashFile = ([string]$CachedMeta.ChecksumHashFile).Trim()
            $cachedHashFrom = ([string]$CachedMeta.ChecksumHashFrom).Trim()
        }
        if ($cachedHash -and $cachedFingerprint -and
                $cachedFingerprint -ieq $result.Fingerprint -and
                $cachedHashFile -eq $hashFile -and $cachedHashFrom -ieq $hashFrom) {
            $result.Hash = $cachedHash
            $result.Skipped = $false
            return $result
        }
        $result.Ok = $false
        $result.Skipped = $false
        $result.Error = ('严格离线模式无法验证 {0}：缓存索引没有与当前 hashFile 声明匹配的已验证校验值；请先在联网环境刷新缓存' -f $FileName)
        return $result
    }

    $text = ''
    try {
        $text = Invoke-WinstHttpGet -Uri $hashFile -Context $Context
    } catch {
        $result.Ok = $false
        $result.Skipped = $false
        $result.Error = ('下载校验文件失败：{0}（{1}）' -f $hashFile, $_.Exception.Message)
        return $result
    }
    $parsed = Get-HashFromChecksumFile -Text $text -FileName $FileName -Rule $hashFrom
    if (-not $parsed.Ok) {
        $result.Ok = $false
        $result.Skipped = $false
        $result.Error = ('{0}（校验文件 {1}）' -f $parsed.Error, $hashFile)
        return $result
    }
    $result.Hash = [string]$parsed.Hash
    $result.Skipped = $false
    return $result
}
