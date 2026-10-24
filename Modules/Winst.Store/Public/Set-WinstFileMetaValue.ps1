#Requires -Version 5.1

function Set-WinstFileMetaValue {
    <#
    .SYNOPSIS
        写入 / 合并某个文件的记账。
    .OUTPUTS
        写入后的容器；容器不可写或文件名为空时原样返回。
    #>
    param(
        $Container,
        [string]$FileName,
        [string]$Url,
        [string]$SourceVersion,
        [string]$ETag,
        [string]$LastModified,
        $Size = $null,
        [string]$DownloadedAt,
        [string]$LastCheckedAt,
        [string]$ExpectedHash,
        [string]$ExpectedAlgorithm,
        [string]$ChecksumHashFile,
        [string]$ChecksumHashFrom,
        [string]$ChecksumFingerprint
    )

    if ($null -eq $Container -or ($Container -isnot [System.Collections.IDictionary])) { return $Container }
    if (-not $FileName) { return $Container }

    $existing = Get-WinstFileMeta -Entry @{ fileMeta = $Container } -FileName $FileName
    $merged = New-WinstFileMetaEntry -Url $existing.Url -SourceVersion $existing.SourceVersion -ETag $existing.ETag `
        -LastModified $existing.LastModified -Size $existing.Size -DownloadedAt $existing.DownloadedAt -LastCheckedAt $existing.LastCheckedAt `
        -ExpectedHash $existing.ExpectedHash -ExpectedAlgorithm $existing.ExpectedAlgorithm `
        -ChecksumHashFile $existing.ChecksumHashFile -ChecksumHashFrom $existing.ChecksumHashFrom `
        -ChecksumFingerprint $existing.ChecksumFingerprint

    if ($PSBoundParameters.ContainsKey('Url') -and $Url) { $merged['url'] = $Url }
    if ($PSBoundParameters.ContainsKey('SourceVersion') -and $SourceVersion) { $merged['sourceVersion'] = $SourceVersion }
    if ($PSBoundParameters.ContainsKey('ETag') -and $ETag) { $merged['etag'] = $ETag }
    if ($PSBoundParameters.ContainsKey('LastModified') -and $LastModified) { $merged['lastModified'] = $LastModified }
    if ($PSBoundParameters.ContainsKey('Size') -and $null -ne $Size) { $merged['size'] = $Size }
    if ($PSBoundParameters.ContainsKey('DownloadedAt') -and $DownloadedAt) { $merged['downloadedAt'] = $DownloadedAt }
    if ($PSBoundParameters.ContainsKey('LastCheckedAt') -and $LastCheckedAt) { $merged['lastCheckedAt'] = $LastCheckedAt }
    # 校验来源字段必须作为一组覆盖（包括显式清空）：hashFile → 字面 hash → hashFile 的切换中，
    # 若空值沿用旧记录，会把新的字面摘要与旧 hashFile 指纹错误配成一组，离线时认证错文件。
    if ($PSBoundParameters.ContainsKey('ExpectedHash')) { $merged['expectedHash'] = ([string]$ExpectedHash).ToLowerInvariant() }
    if ($PSBoundParameters.ContainsKey('ExpectedAlgorithm')) { $merged['expectedAlgorithm'] = ([string]$ExpectedAlgorithm).ToUpperInvariant() }
    if ($PSBoundParameters.ContainsKey('ChecksumHashFile')) { $merged['checksumHashFile'] = [string]$ChecksumHashFile }
    if ($PSBoundParameters.ContainsKey('ChecksumHashFrom')) { $merged['checksumHashFrom'] = [string]$ChecksumHashFrom }
    if ($PSBoundParameters.ContainsKey('ChecksumFingerprint')) { $merged['checksumFingerprint'] = ([string]$ChecksumFingerprint).ToLowerInvariant() }

    $key = $FileName
    foreach ($existingKey in @($Container.Keys)) {
        if ([string]$existingKey -ieq $FileName) { $key = [string]$existingKey; break }
    }
    $Container[$key] = $merged
    return $Container
}
