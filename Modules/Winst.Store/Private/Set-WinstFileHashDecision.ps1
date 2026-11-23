#Requires -Version 5.1

function Set-WinstFileHashDecision {
    <#
    .SYNOPSIS
        ③ 已声明校验时：优先直接比对索引里的摘要，没有记录才现算一次并写回计划。
    .DESCRIPTION
        索引里存两种校验码：hashes = sha256（旧字段，沿用），manifestHashes = 按软件源声明算法的摘要。
        命中判定优先用同算法的那份，直接比对字符串；都没有（旧索引 / 首次）才现算一次。
    #>
    param($Plan, $Entry, [string]$Name, [string]$Target, $Expected)

    $wanted = ([string]$Expected.Hash).ToLowerInvariant()
    $Plan['ExpectedHash'] = $wanted

    $wantedAlgorithm = $Expected.Algorithm
    $Plan['ExpectedAlgorithm'] = $wantedAlgorithm
    $Plan['ChecksumHashFile'] = [string]$Expected.HashFile
    $Plan['ChecksumHashFrom'] = [string]$Expected.HashFrom
    $Plan['ChecksumMetadataAction'] = 'replace'

    if ($wantedAlgorithm -eq 'SHA256') {
        $actual = $Plan['IndexHash']
    } else {
        $actual = Get-WinstManifestHash -Entry $Entry -FileName $Name -Algorithm $wantedAlgorithm
    }

    if (-not $actual) {
        $indexHash = $Plan['IndexHash']
        $actual = Get-WinstPackageFileHash -Path $Target -Algorithm $wantedAlgorithm -IndexHash ([ref]$indexHash)
        $Plan['IndexHash'] = $indexHash
        if (-not $actual) {
            $Plan['NeedDownload'] = $true
            $Plan['ValidationError'] = '无法读取已缓存文件的校验值'
            return
        }
    }
    if ($wantedAlgorithm -ne 'SHA256') { $Plan['ManifestHash'] = $actual }
    if ($actual -ieq $wanted) {
        $Plan['NeedDownload'] = $false
        $Plan['Reason'] = '已缓存且校验码一致'
    } else {
        $Plan['NeedDownload'] = $true
        $Plan['Reason'] = ('已缓存文件校验不通过（缓存 {0}… / 需要 {1}…），将重新下载' -f $actual.Substring(0, [Math]::Min(8, $actual.Length)), $wanted.Substring(0, [Math]::Min(8, $wanted.Length)))
    }
}
