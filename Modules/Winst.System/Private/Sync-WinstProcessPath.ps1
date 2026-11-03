#Requires -Version 5.1

function Sync-WinstProcessPath {
    <#
    .SYNOPSIS
        按机器级、用户级顺序刷新进程 PATH，保留会话独有的路径项。
    .DESCRIPTION
        OldPersistent 是写入前展开的持久 PATH；会话前置项继续前置，其余会话项保留在合并项之后。
    #>
    param([string[]]$OldPersistent = @(), [string]$SessionPath)

    $persistent = @()
    foreach ($scope in @('Machine', 'User')) {
        $raw = Get-WinstEnvironmentValue -Name 'Path' -Scope $scope
        foreach ($part in @(Get-WinstPathSegments -Value ([Environment]::ExpandEnvironmentVariables([string]$raw)))) {
            if (-not (Test-WinstPathSegmentExists -Segments $persistent -Value $part)) { $persistent += $part }
        }
    }
    $before = @()
    $after = @()
    $seenPersistent = $false
    foreach ($part in @(Get-WinstPathSegments -Value $SessionPath)) {
        if (Test-WinstPathSegmentExists -Segments $OldPersistent -Value $part) { $seenPersistent = $true; continue }
        if (Test-WinstPathSegmentExists -Segments $persistent -Value $part) { continue }
        if ($seenPersistent) {
            if (-not (Test-WinstPathSegmentExists -Segments $after -Value $part)) { $after += $part }
        } else {
            if (-not (Test-WinstPathSegmentExists -Segments $before -Value $part)) { $before += $part }
        }
    }
    [Environment]::SetEnvironmentVariable('Path', (@($before) + @($persistent) + @($after) -join ';'), [System.EnvironmentVariableTarget]::Process)
}
