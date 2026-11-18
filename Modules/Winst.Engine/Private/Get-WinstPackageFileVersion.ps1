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

    $name = $FileName.Trim()
    if (-not $PkgDir -or -not $name) { return '' }
    $path = Join-WinstPath $PkgDir $name

    $raw = ''
    try {
        $file = Get-Item -LiteralPath $path -Force -ErrorAction Stop
        $raw = Get-WinstFileResourceVersion -VersionInfo $file.VersionInfo
    } catch {
        return ''
    }
    $raw = $raw.Trim()
    if (-not $raw) { return '' }
    return (Get-NormalizedVersionString -Value $raw)
}
