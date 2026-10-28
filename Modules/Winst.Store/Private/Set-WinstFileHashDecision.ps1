#Requires -Version 5.1

function Set-WinstFileHashDecision {
    <#
    .SYNOPSIS
        ③ 已声明校验时：优先直接比对索引里的摘要，没有记录才现算一次并写回计划。
    .DESCRIPTION
        索引里存两种校验码：hashes = sha256（旧字段，沿用），manifestHashes = 按软件源声明算法的摘要。
        命中判定优先用同算法的那份，直接比对字符串；都没有（旧索引 / 首次）才现算一次。
    #>
    param($Plan, $Entry, [string]$Name, [string]$Target, $Expected, [switch]$ForceRehash)

    $wanted = ([string]$Expected.Hash).ToLowerInvariant()
    $Plan['ExpectedHash'] = $wanted

    $wantedAlgorithm = Get-HashAlgorithmFromDigestLength -Length $wanted.Length
    if (-not $wantedAlgorithm) { $wantedAlgorithm = 'SHA256' }
    $Plan['ExpectedAlgorithm'] = $wantedAlgorithm
    $Plan['ChecksumHashFile'] = [string]$Expected.HashFile
    $Plan['ChecksumHashFrom'] = [string]$Expected.HashFrom
    $Plan['ChecksumFingerprint'] = [string]$Expected.Fingerprint
    $Plan['ChecksumMetadataAction'] = 'replace'

    $recordedSha256 = Get-WinstRecordedHash -Entry $Entry -FileName $Name
    if ($recordedSha256 -and $wantedAlgorithm -ne 'SHA256') {
        # 期望算法不是 sha256 时索引里的 sha256 不参与比对，但仍要带回给调用方写回索引
        $Plan['IndexHash'] = $recordedSha256
    }

    $recorded = ''
    if ($wantedAlgorithm -eq 'SHA256') {
        $recorded = $recordedSha256
    } else {
        $recorded = Get-WinstManifestHash -Entry $Entry -FileName $Name -Algorithm $wantedAlgorithm
    }

    if ($recorded -and -not $ForceRehash) {
        if ($wantedAlgorithm -eq 'SHA256') { $Plan['RecordedHash'] = $recorded } else { $Plan['ManifestHash'] = $recorded }
        if ($recorded -ieq $wanted) {
            $Plan['NeedDownload'] = $false
            $Plan['Reason'] = '已缓存且校验码一致'
        } else {
            $Plan['NeedDownload'] = $true
            $Plan['Reason'] = ('已缓存文件的校验码与软件源不一致（缓存 {0}… / 需要 {1}…）' -f $recorded.Substring(0, [Math]::Min(8, $recorded.Length)), $wanted.Substring(0, [Math]::Min(8, $wanted.Length)))
        }
        return
    }

    $actual = ''
    try { $actual = (Get-WinstFileHash -Path $Target -Algorithm $wantedAlgorithm) } catch { $actual = '' }
    if (-not $actual) {
        # 同样显式表态：读不出校验值 = 无法确认缓存可信，必须重新下载
        $Plan['NeedDownload'] = $true
        $Plan['Reason'] = '无法读取已缓存文件的校验值'
        return
    }
    $actual = ([string]$actual).ToLowerInvariant()
    if ($wantedAlgorithm -eq 'SHA256') {
        $Plan['RecordedHash'] = $actual
    } else {
        # 期望算法不是 sha256，本次算出的摘要按「软件源声明摘要」写回索引，供下次直接比对
        $Plan['ManifestHash'] = $actual
    }
    if ($actual -ieq $wanted) {
        $Plan['NeedDownload'] = $false
        $Plan['Reason'] = '已缓存且校验通过（校验码已写入索引）'
    } else {
        $Plan['NeedDownload'] = $true
        $Plan['Reason'] = ('已缓存文件校验不通过（缓存 {0}… / 需要 {1}…），将重新下载' -f $actual.Substring(0, [Math]::Min(8, $actual.Length)), $wanted.Substring(0, [Math]::Min(8, $wanted.Length)))
    }
}
