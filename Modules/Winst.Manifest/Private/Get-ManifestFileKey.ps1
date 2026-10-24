#Requires -Version 5.1

function Get-ManifestFileKey {
    <#
    .SYNOPSIS
        把软件源名称（用户名/仓库）映射为可作文件名的键。
    .DESCRIPTION
        Windows 文件名不能含 `/`，故把「用户名/仓库」映射为「用户名__仓库」；
        GitHub 用户名不含下划线，因此该映射不会与其它来源名冲突。
    #>
    param([string]$Name)

    if (-not $Name) { return '' }
    $key = ([string]$Name).Replace('/', '__')
    if (Test-WinstSafePathSegment -Name $key) { return $key }

    # 源名里可能带 `\`、`.`、`..`、`:`（用户可以手输，共享的 sources.json 也可能被改写）：
    # 这种名字绝不能拼进路径，退化成稳定的哈希键（同一来源每次得到同一个键）。
    try {
        $sha = [Security.Cryptography.SHA256]::Create()
        $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes([string]$Name))).Replace('-', '').ToLowerInvariant()
        return ('unsafe-' + $hash.Substring(0, 32))
    } catch {
        return ''
    }
}
