#Requires -Version 5.1

function Get-WinstDownloadTaskRecords {
    param([string]$DestDir)

    $path = Get-WinstFluxTaskPath $DestDir
    $tasks = Split-Path -Parent $path
    $records = @{}
    if (-not (Test-Path -LiteralPath $tasks -PathType Container -ErrorAction Stop)) { return $records }

    $legacy = @{}
    foreach ($file in Get-ChildItem -LiteralPath $tasks -File -Force -ErrorAction Stop) {
        # 原子写入中断可能留下未提交或只写了一部分的临时文档。
        if ($file.Name -match '\.tmp-[0-9a-f]{8}$') { continue }
        Assert-WinstSafeWritePath -Path $file.FullName
        $document = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $files = Get-EntryValue $document 'files'
        if ($file.FullName -eq $path -and $files -is [pscustomobject]) {
            foreach ($item in $files.PSObject.Properties) {
                if (-not (Test-WinstSafePathSegment -Name $item.Name) -or $item.Value -isnot [pscustomobject]) {
                    throw ('下载记录包含无效文件：' + $path)
                }
                $records[$item.Name] = [hashtable](Copy-WinstObjectShallow $item.Value)
            }
        } elseif ((Get-EntryString $document 'address') -and (Get-EntryString $document 'computer')) {
            if (-not (Test-WinstSafePathSegment -Name $file.Name)) { throw ('下载记录包含无效文件：' + $file.FullName) }
            $legacy[$file.Name] = [hashtable](Copy-WinstObjectShallow $document)
        } elseif ($file.FullName -eq $path) { throw ('下载记录缺少文件列表：' + $path) }
    }
    if ($legacy.Count) {
        # 同一任务可以补齐标识和指纹。两个非空值冲突时保留原文件供核实。
        foreach ($name in $legacy.Keys) {
            if (-not $records.ContainsKey($name)) { $records[$name] = $legacy[$name]; continue }
            $old = $legacy[$name]
            $current = $records[$name]
            $legacyWorkId = Get-EntryString $old 'workId'
            if (-not $legacyWorkId -and $current['workId']) { continue }
            if ($legacyWorkId -ne [string]$current['workId'] -or $old.address -cne $current['address'] -or
                    $old.computer -ne $current['computer'] -or (Get-EntryBool $old 'magnet') -ne (Get-EntryBool $current 'magnet') -or
                    (Get-EntryString $old 'version') -cne (Get-EntryString $current 'version') -or
                    (Get-EntryString $old 'hash') -ne (Get-EntryString $current 'hash')) {
                throw ('存在冲突的下载任务：' + $name)
            }
            foreach ($key in @('taskId', 'request', 'urlFingerprint')) {
                $value = Get-EntryString $old $key
                if (-not $value) { continue }
                if ($current[$key] -and $current[$key] -cne $value) {
                    throw ('下载任务 {0} 的 {1} 冲突，请核对 {2} 中的记录' -f $name, $key, $tasks)
                }
                $current[$key] = $value
            }
        }
        Write-FileAtomic -Path $path -Content (ConvertTo-Json @{ files = $records } -Depth 12 -Compress)
        foreach ($name in $legacy.Keys) {
            $oldPath = Join-Path $tasks $name
            if ($oldPath -ne $path) { Remove-Item -LiteralPath $oldPath -ErrorAction Stop }
        }
    }
    return $records
}
