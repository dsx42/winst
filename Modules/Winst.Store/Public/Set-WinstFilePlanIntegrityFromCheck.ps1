#Requires -Version 5.1

function Set-WinstFilePlanIntegrityFromCheck {
    <#
    .SYNOPSIS
        把 Test-WinstFileIntegrity 的结果写回 filePlan，供下载循环与引擎引导共用。
    #>
    param(
        [Parameter(Mandatory = $true)]$FilePlan,
        [Parameter(Mandatory = $true)]$Check
    )

    if ($Check.IndexHash) { $FilePlan['RecordedHash'] = [string]$Check.IndexHash }
    if ($Check.ActualHash -and $Check.Algorithm -and $Check.Algorithm -ne 'SHA256') {
        $FilePlan['ManifestHash'] = ([string]$Check.ActualHash).ToLowerInvariant()
    }
    $FilePlan['ExpectedHash'] = [string]$Check.ExpectedHash
    $FilePlan['ExpectedAlgorithm'] = [string]$Check.Algorithm
    $FilePlan['ChecksumHashFile'] = [string]$Check.ChecksumHashFile
    $FilePlan['ChecksumHashFrom'] = [string]$Check.ChecksumHashFrom
    $FilePlan['ChecksumFingerprint'] = [string]$Check.ChecksumFingerprint
    $FilePlan['ChecksumMetadataAction'] = 'replace'
}
