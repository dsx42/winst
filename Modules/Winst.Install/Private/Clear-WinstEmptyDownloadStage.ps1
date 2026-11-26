#Requires -Version 5.1

function Clear-WinstEmptyDownloadStage {
    <#
    .SYNOPSIS
        在条目锁内清理空下载目录。全部文件登记成功后，再清除被取代的旧文件。
    #>
    param([string]$PkgDir, [switch]$DownloadComplete)

    $stage = Join-WinstPath $PkgDir 'winst-download'
    if (-not (Test-Path -LiteralPath $stage -ErrorAction Stop)) { return }
    Assert-WinstSafeWritePath -Path $stage -Directory
    $tasks = Join-WinstPath $stage '.tasks'
    $local = Join-WinstPath $stage '.local'
    if ($DownloadComplete) {
        Assert-WinstSafeWritePath -Path $tasks -Directory
        Clear-WinstInstallDir -Dir (Join-WinstPath $tasks 'replaced') -AllowedRoot $stage -Strict
    }
    $containers = @()
    foreach ($path in @($tasks, $local)) {
        if (-not (Test-Path -LiteralPath $path -PathType Container -ErrorAction Stop)) { continue }
        Assert-WinstSafeWritePath -Path $path -Directory
        if ($path -eq $local) {
            foreach ($dir in Get-ChildItem -LiteralPath $local -Directory -Force -ErrorAction Stop) {
                if ($DownloadComplete) {
                    Assert-WinstSafeWritePath -Path $dir.FullName -Directory
                    # failed 仅存放已退出的本地下载，新计划可能使用了不同文件名。
                    Clear-WinstInstallDir -Dir (Join-WinstPath $dir.FullName 'failed') -AllowedRoot $local -Strict
                }
                $containers += $dir.FullName
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
                    Write-Warning ('已保留下载文件：' + $child.FullName)
                }
            }
        }
    }
}
