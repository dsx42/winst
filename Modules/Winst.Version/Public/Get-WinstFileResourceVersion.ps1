#Requires -Version 5.1

function Get-WinstFileResourceVersion {
    <#
    .SYNOPSIS
        从 Windows 文件版本资源取可识别的版本。字符串与数值前缀一致时优先保留原文。
    #>
    param($VersionInfo)

    if (-not $VersionInfo) { return '' }
    $number = ConvertTo-WinstFileVersionText -Text ([string]$VersionInfo.FileVersionRaw)
    if (-not $number -or $number -match '^0(?:\.0)*$') {
        $number = ConvertTo-WinstFileVersionText -Text ([string]$VersionInfo.ProductVersionRaw)
        if ($number -match '^0(?:\.0)*$') { $number = '' }
    }
    $raw = ConvertTo-WinstFileVersionText -Text ([string]$VersionInfo.FileVersion)
    if (-not $raw) { $raw = ConvertTo-WinstFileVersionText -Text ([string]$VersionInfo.ProductVersion) }
    if ($number -and -not (Test-WinstNumericVersionPrefix -Prefix $raw -Value $number)) { return $number }
    return $raw
}
