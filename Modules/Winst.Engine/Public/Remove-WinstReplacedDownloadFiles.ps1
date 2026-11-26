#Requires -Version 5.1

function Remove-WinstReplacedDownloadFiles {
    <#
    .SYNOPSIS
        在条目锁内清理未绑定的空工作目录及已被正式包取代的下载文件，返回是否清除了残留。
    #>
    param([string]$DestDir, [hashtable]$Config, [string[]]$FileNames, [switch]$DuplicatesOnly)

    if (-not (Test-Path -LiteralPath $DestDir -PathType Container)) { return $false }
    Assert-WinstSafeWritePath -Path $DestDir -Directory
    $currentPath = Get-WinstFluxTaskPath $DestDir
    $records = Get-WinstDownloadTaskRecords $DestDir
    $bound = @($records.Values | ForEach-Object { Get-EntryString $_ 'workId' })
    $dirs = @(Get-ChildItem -LiteralPath $DestDir -Directory -Force -ErrorAction Stop |
        Where-Object { $_.Name -match '^[0-9a-f]{32}$' -and $_.Name -notin $bound })

    $files = @{}
    foreach ($name in $FileNames) {
        if (-not (Test-WinstSafePathSegment -Name $name)) { throw '已登记文件名无效' }
        if ($records.ContainsKey($name)) { continue }
        $path = Join-Path (Split-Path -Parent $DestDir) $name
        Assert-WinstSafeWritePath -Path $path
        if (Test-Path -LiteralPath $path -PathType Leaf) { $files[$name] = $path }
    }

    $tasks = @()
    $options = Get-WinstState -Name WinstOptions
    if ($dirs.Count -and -not ($options -and $options.Offline)) {
        try {
            $service = Get-WinstFluxService -Config $Config
            $tasks = @(Invoke-WinstFluxApi $service GET 'tasks' -Reconnect)
        } catch { Write-Verbose ('无法核实 FluxDown 任务，仅核对完整文件：' + $_.Exception.Message) }
    }
    $changed = $false
    $pending = @{}
    $completed = @{}
    foreach ($dir in $dirs) {
        Assert-WinstSafeWritePath -Path $dir.FullName -Directory
        $matches = @($tasks | Where-Object { $_ -and $_.saveDir -eq $dir.FullName })
        $task = if ($matches.Count -eq 1) { $matches[0] }
        if ($matches.Count -gt 1 -or ($task -and ($task.status -notin @(2,3,4) -or -not $files.ContainsKey([string]$task.fileName)))) {
            foreach ($one in $matches) { $pending[[string]$one.fileName] = $true }
            continue
        }
        $release = {
            $id = [string]$task.taskId
            if (-not [guid]::TryParse($id, [ref]([guid]::Empty))) { throw '服务任务 ID 无效' }
            $detail = Invoke-WinstFluxApi $service GET ('tasks/' + $id) -Reconnect
            if (-not $detail -or $detail.saveDir -ne $dir.FullName -or $detail.taskId -ne $id -or
                $detail.fileName -ne $task.fileName -or $detail.status -notin @(2,3,4)) { return $false }
            if ($detail.status -in @(2,4)) {
                $null = Invoke-WinstFluxApi $service DELETE ('tasks/' + $id + '?deleteFiles=false')
            }
            return $true
        }
        if ($task -and -not $DuplicatesOnly) {
            if (-not (& $release)) { $pending[[string]$task.fileName] = $true; continue }
            Clear-WinstInstallDir -Dir $dir.FullName -AllowedRoot $DestDir -Strict
            $completed[[string]$task.fileName] = $true
            $changed = $true
            continue
        }

        foreach ($child in Get-ChildItem -LiteralPath $dir.FullName -Force -ErrorAction Stop) {
            if ($child.PSIsContainer -or -not $files.ContainsKey($child.Name)) {
                if ($child.Name.EndsWith('.fdownloading', [StringComparison]::OrdinalIgnoreCase)) {
                    $pending[[IO.Path]::GetFileNameWithoutExtension($child.Name)] = $true
                }
                continue
            }
            if ($task -and $task.fileName -ne $child.Name) { continue }
            Assert-WinstSafeWritePath -Path $child.FullName
            $source = $null
            $formal = $null
            $sha = $null
            try {
                # 保持禁止写入的句柄直到删除，避免校验后把仍在写入的分段误删。
                $source = [IO.File]::Open($child.FullName, 'Open', 'Read', 'Delete')
                $formal = [IO.File]::Open($files[$child.Name], 'Open', 'Read', 'Read')
                $sha = [Security.Cryptography.SHA256]::Create()
                if ($source.Length -ne $formal.Length -or
                    [BitConverter]::ToString($sha.ComputeHash($source)) -ne [BitConverter]::ToString($sha.ComputeHash($formal))) {
                    $pending[$child.Name] = $true
                    continue
                }
                if ($task -and -not (& $release)) { $pending[$child.Name] = $true; continue }
                [IO.File]::Delete($child.FullName)
                $completed[$child.Name] = $true
                $changed = $true
            } catch [IO.IOException] {
                $pending[$child.Name] = $true
                Write-Verbose ('保留下载文件：' + $_.Exception.Message)
            } finally {
                if ($sha) { $sha.Dispose() }
                if ($formal) { $formal.Dispose() }
                if ($source) { $source.Dispose() }
            }
        }
        if (-not (Get-ChildItem -LiteralPath $dir.FullName -Force -ErrorAction Stop | Select-Object -First 1)) {
            [IO.Directory]::Delete($dir.FullName, $false)
            $changed = $true
        }
    }

    foreach ($name in $files.Keys) {
        if ($pending.ContainsKey($name) -or ($DuplicatesOnly -and -not $completed.ContainsKey($name))) { continue }
        $marker = Join-Path (Split-Path -Parent $currentPath) $name
        if ($marker -eq $currentPath -or -not (Test-Path -LiteralPath $marker -PathType Leaf)) { continue }
        Assert-WinstSafeWritePath -Path $marker
        Remove-Item -LiteralPath $marker -ErrorAction Stop
        $changed = $true
    }
    return $changed
}
