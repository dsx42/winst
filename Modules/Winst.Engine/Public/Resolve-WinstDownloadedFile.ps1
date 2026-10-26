#Requires -Version 5.1

function Resolve-WinstDownloadedFile {
    <#
    .SYNOPSIS
        把引擎改名过的下载产物归位成期望文件名（只在**本次新出现**的文件里认领）。
    .DESCRIPTION
        引擎在目标名被占用时会把输出写成「名称 (1).zip」——下载其实成功了，但 winst 按期望名找不到
        文件，会一直重试。这里按调用方给的「下载前目录快照」只认本次
        新出现、且不是 `.fdownloading` 的文件：恰好一个 → 改名成期望名并返回它；没有 / 多个 → 不猜，
        交给调用方报错（多个时列出文件名）。期望名本来就在（正常下载）时直接返回它。
    .OUTPUTS
        @{ Path; Note; Error }
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$Name,
        $BeforeFiles = $null
    )

    $result = @{ Path = ''; Note = ''; Error = '' }
    $target = Join-WinstPath $Dir $Name
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        $result.Path = $target
        return $result
    }

    $before = New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($item in @($BeforeFiles)) {
        if ($null -ne $item) { $before[[string]$item] = $true }
    }

    $candidates = @()
    foreach ($file in @(Get-ChildItem -LiteralPath $Dir -File -Force -ErrorAction SilentlyContinue)) {
        if ($before.ContainsKey([string]$file.Name)) { continue }
        if ($file.Name -like '*.fdownloading') { continue }
        $candidates += $file
    }

    if ($candidates.Count -eq 0) {
        $result.Error = '本次下载没有产生新文件'
        return $result
    }
    if ($candidates.Count -gt 1) {
        $result.Error = ('本次下载产生了多个新文件，无法确定哪一个是目标：{0}' -f (($candidates | ForEach-Object { $_.Name }) -join '、'))
        return $result
    }

    try {
        Move-Item -LiteralPath $candidates[0].FullName -Destination $target -Force -ErrorAction Stop
        $result.Path = $target
        $result.Note = ('下载引擎把文件名写成了「{0}」，已自动改回期望的「{1}」' -f $candidates[0].Name, $Name)
    } catch {
        $result.Error = ('把下载结果改名为「{0}」失败：{1}' -f $Name, $_.Exception.Message)
    }
    return $result
}
