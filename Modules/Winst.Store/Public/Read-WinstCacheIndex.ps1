#Requires -Version 5.1

function Read-WinstCacheIndex {
    <#
    .SYNOPSIS
        读取缓存索引；缺失或损坏时按各 id 目录内的文件重建。
    .OUTPUTS
        @{ Index; Rebuilt; Changed; Error }
    .DESCRIPTION
        重建时版本未知（记空串），并按文件的最后写入时间填 downloadedAt；目录已不存在的索引条目
        在本次读取中清除（Changed 为 $true 时调用方应回写）。
        整份文件读不出来才算「损坏」：单条记录解析失败只按该 id 目录内的文件重建这一条，
        不牵连其余记录；判定损坏时先把原文件另存为 winst.json.bak 再交给调用方覆盖，
        避免一条解析异常就把全体的版本 / 校验码 / 新鲜度基线一起清空。
    #>
    param([Parameter(Mandatory = $true)][string]$PkgDir)

    $result = @{
        Index   = (New-WinstOrdinalDictionary)
        Rebuilt = $false
        Changed = $false
        Error   = ''
    }

    $path = Get-WinstCacheIndexPath -PkgDir $PkgDir

    # 整个结果按 (索引文件时间戳, 长度) 缓存：一次安装流程会为每条文件计划、每条新鲜度提示各读一次，
    # 缓存命中可省去全量 JSON 解析，但仍逐 id 核对目录，避免外部删目录后沿用旧结果。
    # 写入侧 Save-WinstCacheIndex 走 Write-FileAtomic 自动失效；索引文件被删除 / 重建时时间戳变化，同样自动失效。
    $cacheKey = 'cache-index|' + $path
    # 注意：变量名不能叫 $stamp —— 别处 $stamp 表示「下载时间」（见 New-WinstCacheIndexEntryFromDir），容易混淆
    $indexFileStamp = Get-WinstFileStamp -Path $path
    $cachedIndex = (Get-WinstState -Name WinstJsonCache)[$cacheKey]
    if ($cachedIndex -and ([string]$cachedIndex['Stamp'] -eq $indexFileStamp)) {
        $cachedResult = $cachedIndex['Value']
        $result.Rebuilt = [bool]$cachedResult.Rebuilt
        $result.Changed = [bool]$cachedResult.Changed
        $result.Error = [string]$cachedResult.Error
        foreach ($id in @($cachedResult.Index.Keys)) {
            $dir = Join-Path $PkgDir $id
            if (Test-Path -LiteralPath $dir -PathType Container) {
                $result.Index[$id] = $cachedResult.Index[$id]
            } else {
                $result.Changed = $true
            }
        }
        return $result
    }

    $loaded = $false
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        try {
            $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8
            if ($raw -and $raw.Trim()) {
                $obj = $raw | ConvertFrom-Json
                if ($null -ne $obj) {
                    foreach ($prop in $obj.PSObject.Properties) {
                        $id = [string]$prop.Name
                        if (-not $id) { continue }
                        # 单条记录读坏只影响这一条：记忆里没有它时按目录内的文件重建一条（版本记空串，
                        # 安装 / 下载时自动核对并回写）；这里**不置 Changed**——原文件里那条记录可能本来是好的，
                        # 整份回写会把它一并抹掉，留着原文等下次真正需要写盘时再说
                        $entry = $null
                        try {
                            $entry = ConvertTo-WinstCacheIndexEntry -Entry $prop.Value
                        } catch {
                            $entry = New-WinstCacheIndexEntryFromDir -Dir (Join-Path $PkgDir $id)
                        }
                        if ($null -ne $entry) { $result.Index[$id] = $entry }
                    }
                    $loaded = $true
                }
            }
        } catch {
            $loaded = $false
        }
    }

    if (-not $loaded) {
        $result.Rebuilt = $true
        $result.Changed = $true
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $result.Error = '安装包索引损坏，已按各软件目录内的文件重建。'
            # 覆盖前留一份旧文件：重建后的记录没有版本 / 校验码 / 新鲜度基线，万一是解析口径的问题
            # （而不是文件真坏了），还能照着重找回来。同一份坏文件只留一次（备份比原文件新就不再复制）
            try {
                $backup = $path + '.bak'
                $needCopy = -not (Test-Path -LiteralPath $backup -PathType Leaf)
                if (-not $needCopy) {
                    $needCopy = (Get-Item -LiteralPath $backup).LastWriteTimeUtc -lt (Get-Item -LiteralPath $path).LastWriteTimeUtc
                }
                if ($needCopy) { Copy-Item -LiteralPath $path -Destination $backup -Force -ErrorAction Stop }
            } catch { }
        }
    }

    # 索引里指向已不存在目录的条目：清除（下次写入时一并落盘）
    foreach ($id in @($result.Index.Keys)) {
        $dir = Join-Path $PkgDir $id
        if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
            $result.Index.Remove($id)
            $result.Changed = $true
        }
    }

    if ($result.Rebuilt) {
        foreach ($dir in @(Get-ChildItem -LiteralPath $PkgDir -Directory -ErrorAction SilentlyContinue)) {
            $id = $dir.Name
            if ($id -ieq 'manifests') { continue }
            $entry = New-WinstCacheIndexEntryFromDir -Dir $dir.FullName
            if ($null -ne $entry) { $result.Index[$id] = $entry }
        }
    }

    (Get-WinstState -Name WinstJsonCache)[$cacheKey] = @{ Stamp = $indexFileStamp; Value = $result; Raw = '' }
    return $result
}
