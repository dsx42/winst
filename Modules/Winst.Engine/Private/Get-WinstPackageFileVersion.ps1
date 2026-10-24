#Requires -Version 5.1

function Get-WinstPackageFileVersion {
    <#
    .SYNOPSIS
        从已下载的主包文件信息里取版本号。
    .DESCRIPTION
        面向「下载页上没有版本号，只能等安装包下载下来后看文件信息」的软件（如 MSVC 可再发行组件）：
        读主包文件的 FileVersion，取不到再退 ProductVersion；文件不在缓存里或没有版本信息时返回空串。
    #>
    param([string]$PkgDir, [string]$FileName)

    $name = ''
    if ($null -ne $FileName) { $name = ([string]$FileName).Trim() }
    if (-not $PkgDir -or -not $name) { return '' }
    $path = Join-Path $PkgDir $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return '' }

    $raw = ''
    try {
        $file = Get-Item -LiteralPath $path -Force -ErrorAction Stop
        $vi = $file.VersionInfo
        if ($vi) {
            # 与 fileVersion 检测同一口径：字符串是数值体的数字前缀时按字符串算，否则以数值体为准
            $rawNumber = ConvertTo-WinstFileVersionText -Text ([string]$vi.FileVersionRaw)
            if (-not $rawNumber) { $rawNumber = ConvertTo-WinstFileVersionText -Text ([string]$vi.ProductVersionRaw) }
            $raw = ConvertTo-WinstFileVersionText -Text ([string]$vi.FileVersion)
            if (-not $raw) { $raw = ConvertTo-WinstFileVersionText -Text ([string]$vi.ProductVersion) }
            if ($rawNumber -and -not (Test-WinstNumericVersionPrefix -Prefix $raw -Value $rawNumber)) {
                $raw = $rawNumber
            }
            if (-not $raw) { $raw = ConvertTo-WinstFileVersionText -Text ([string]$vi.FileVersionRaw) }
            if (-not $raw) { $raw = ConvertTo-WinstFileVersionText -Text ([string]$vi.ProductVersionRaw) }
        }
    } catch {
        return ''
    }
    $raw = $raw.Trim()
    if (-not $raw) { return '' }
    return (Get-NormalizedVersionString -Value $raw)
}
