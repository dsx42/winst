#Requires -Version 5.1

function Clear-WinstEmptyDownloadStage {
    <#
    .SYNOPSIS
        在条目锁内收起空的下载暂存目录，提示仍需核实的任务和断点。
    #>
    param([string]$PkgDir)

    $stage = Join-WinstPath $PkgDir 'winst-download'
    if (-not (Test-Path -LiteralPath $stage -ErrorAction Stop)) { return }
    Assert-WinstSafeWritePath -Path $stage -Directory
    $tasks = Join-WinstPath $stage '.tasks'
    $local = Join-WinstPath $stage '.local'
    $containers = @()
    foreach ($path in @($tasks, $local)) {
        if (-not (Test-Path -LiteralPath $path -PathType Container -ErrorAction Stop)) { continue }
        Assert-WinstSafeWritePath -Path $path -Directory
        if ($path -eq $local) {
            foreach ($dir in Get-ChildItem -LiteralPath $local -Directory -Force -ErrorAction Stop) {
                if (-not (Test-Path -LiteralPath (Join-WinstPath $tasks $dir.Name) -ErrorAction Stop)) {
                    $containers += $dir.FullName
                }
            }
        }
        $containers += $path
    }
    foreach ($path in @($containers) + $stage) {
        Assert-WinstSafeWritePath -Path $path -Directory
        $children = @(Get-ChildItem -LiteralPath $path -Force -ErrorAction Stop)
        if (-not $children.Count) {
            # 独立 CLI 可在父进程退出后继续写入。只删除当下仍为空的目录。
            [IO.Directory]::Delete($path, $false)
        } elseif ($path -in @($tasks, $stage)) {
            foreach ($child in $children) {
                if ($child.FullName -ne $tasks) {
                    Write-Warning ('保留待核实的下载暂存：' + $child.FullName)
                }
            }
        }
    }
}
