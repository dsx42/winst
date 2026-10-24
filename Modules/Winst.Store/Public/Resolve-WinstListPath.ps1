#Requires -Version 5.1

function Resolve-WinstListPath {
    <#
    .SYNOPSIS
        把用户输入归一化为清单文件绝对路径。
    .DESCRIPTION
        含路径分隔符或盘符时按「绝对路径 / 相对当前目录」解析；否则按 <数据根>\lists\<文件名> 解析，
        并统一强制 .list 后缀。
    .OUTPUTS
        @{ Ok; Error; Path }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string]$Text
    )

    $raw = ''
    if ($null -ne $Text) { $raw = ([string]$Text).Trim().Trim('"') }
    if (-not $raw) { return @{ Ok = $false; Error = '文件名为空。'; Path = '' } }

    $listsDir = Get-WinstListsDir -Context $Context
    if ($raw -match '[\\/]' -or $raw -match '^[A-Za-z]:') {
        # 显式路径：归一化后必须落在 <数据根>\lists 之下。跳过文件名校验的话，
        # `..\..\Windows\System32\x`、`%APPDATA%\...\Startup\x` 都会被接受并交给 Save-WinstList
        # （Write-FileAtomic 会自动建目录 + 覆盖写），等于任意位置写文件。
        $full = $raw
        if (-not [IO.Path]::IsPathRooted($full)) {
            try { $full = (Join-Path (Get-Location).Path $full) } catch { }
        }
        if ($full -notmatch '(?i)\.list$') { $full = $full + '.list' }
        try { $full = [IO.Path]::GetFullPath($full) } catch {
            return @{ Ok = $false; Error = '清单文件路径不合法。'; Path = '' }
        }
        if (-not (Test-WinstPathUnderRoot -Path $full -Root $listsDir)) {
            return @{ Ok = $false; Error = ('清单文件只能放在 {0} 目录下（不接受 .. 或其它目录的绝对路径）。' -f $listsDir); Path = '' }
        }
        return @{ Ok = $true; Error = ''; Path = $full }
    }

    $checked = Test-WinstListFileName -Text $raw
    if (-not $checked.Ok) { return @{ Ok = $false; Error = $checked.Error; Path = '' } }
    return @{ Ok = $true; Error = ''; Path = (Join-Path $listsDir ([string]$checked.Name)) }
}
