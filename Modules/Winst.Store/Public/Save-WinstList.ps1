#Requires -Version 5.1

function Save-WinstList {
    <#
    .SYNOPSIS
        写入行式清单。
    .DESCRIPTION
        先写注释行、再按传入顺序写 `id` 或 `id==版本`；目录不存在时由 Write-FileAtomic 自动创建。
        `--dry-run` 下不落盘，只把 Count 记为将写入的项数并返回同一结构。
    .OUTPUTS
        @{ Ok; Error; Path; Count; DryRun }
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string[]]$CommentLines = @(),
        [string[]]$Ids = @(),
        $VersionById = $null,
        [switch]$DryRun
    )

    $result = @{ Ok = $false; Error = ''; Path = $Path; Count = 0; DryRun = [bool]$DryRun }

    $lines = @()
    foreach ($one in @($CommentLines)) {
        $text = [string]$one
        if ($text) { $lines += $text }
    }
    $count = 0
    foreach ($one in @($Ids)) {
        $id = [string]$one
        if (-not $id) { continue }
        $version = ''
        if ($VersionById -and $VersionById.Contains($id)) { $version = [string]$VersionById[$id] }
        if ($version) { $lines += ('{0}=={1}' -f $id, $version) } else { $lines += $id }
        $count++
    }
    $result.Count = $count

    if ($DryRun) { $result.Ok = $true; return $result }

    $content = ''
    if ($lines.Count -gt 0) { $content = (($lines -join [Environment]::NewLine) + [Environment]::NewLine) }
    try {
        Write-FileAtomic -Path $Path -Content $content
        $result.Ok = $true
    } catch {
        $result.Error = ('写入清单失败: {0}' -f $_.Exception.Message)
    }
    return $result
}
