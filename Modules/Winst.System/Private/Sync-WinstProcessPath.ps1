#Requires -Version 5.1

function Sync-WinstProcessPath {
    <#
    .SYNOPSIS
        按机器级、用户级顺序刷新进程 PATH，保留会话独有的路径项。
    .DESCRIPTION
        OldPersistent 是写入前展开的持久 PATH；会话前置项继续前置，其余会话项保留在合并项之后。
    #>
    param([string[]]$OldPersistent = @(), [string]$SessionPath)

    $persistent = New-Object 'System.Collections.Generic.List[string]'
    $persistentKeys = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::InvariantCultureIgnoreCase)
    foreach ($scope in @('Machine', 'User')) {
        $raw = Get-WinstEnvironmentValue -Name 'Path' -Scope $scope
        foreach ($part in @(Get-WinstPathSegments -Value ([Environment]::ExpandEnvironmentVariables([string]$raw)))) {
            if ($persistentKeys.Add($part.Trim().Trim('"'))) { $persistent.Add($part) }
        }
    }
    $oldKeys = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::InvariantCultureIgnoreCase)
    foreach ($part in $OldPersistent) { [void]$oldKeys.Add($part.Trim().Trim('"')) }
    $before = New-Object 'System.Collections.Generic.List[string]'
    $after = New-Object 'System.Collections.Generic.List[string]'
    $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::InvariantCultureIgnoreCase)
    $outputParts = $before
    foreach ($part in @(Get-WinstPathSegments -Value $SessionPath)) {
        $key = $part.Trim().Trim('"')
        if ($oldKeys.Contains($key)) {
            if ([object]::ReferenceEquals($outputParts, $before)) { $seen.Clear(); $outputParts = $after }
            continue
        }
        if (-not $persistentKeys.Contains($key) -and $seen.Add($key)) { $outputParts.Add($part) }
    }
    [Environment]::SetEnvironmentVariable('Path', ($before.ToArray() + $persistent.ToArray() + $after.ToArray() -join ';'), [System.EnvironmentVariableTarget]::Process)
}
