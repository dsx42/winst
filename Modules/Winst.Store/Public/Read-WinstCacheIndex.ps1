#Requires -Version 5.1

function Read-WinstCacheIndex {
    <#
    .SYNOPSIS
        读取缓存索引；缺失或损坏时按各 id 目录内的文件重建。
    .OUTPUTS
        @{ Index; Rebuilt; Changed; Error; CanSave; BackupError }
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
        CanSave = $true
        BackupError = ''
    }

    $path = Get-WinstCacheIndexPath -PkgDir $PkgDir

    # 整个结果按 (索引文件时间戳, 长度) 缓存：一次安装流程会为每条文件计划、每条新鲜度提示各读一次，
    # 缓存命中可省去全量 JSON 解析，但仍需核对目录是否还在（外部删目录后不能沿用旧结果）。
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
        $result.CanSave = [bool]$cachedResult.CanSave
        $result.BackupError = [string]$cachedResult.BackupError

        # 一次枚举拿到现存 id 集合，替代「逐 id 一次 Test-Path」：
        # 后者在几百个 id 时是数百次独立 stat（实测 300 条约 112 ms，一次枚举约 8 ms）。
        # 等价性：id 目录存在 ⇔ 名字出现在 -Directory 枚举结果里；
        # 用 OrdinalIgnoreCase 对齐 Windows 文件系统「不区分大小写」的实际行为。
        $existingIds = New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase)
        if (Test-Path -LiteralPath $PkgDir -PathType Container) {
            foreach ($dir in @(Get-ChildItem -LiteralPath $PkgDir -Directory -Force -ErrorAction SilentlyContinue)) {
                $existingIds[[string]$dir.Name] = $true
            }
        }

        foreach ($id in @($cachedResult.Index.Keys)) {
            if ($existingIds.ContainsKey([string]$id)) {
                # 按条目复制：调用方会就地修改 Index 里的条目，共享引用等于改到缓存本体
                $result.Index[$id] = Copy-WinstObjectShallow -InputObject $cachedResult.Index[$id]
            } else {
                $result.Changed = $true
            }
        }
        return $result
    }

    $loaded = $false
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        try {
            $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8 -ErrorAction Stop
            if ($raw -and $raw.Trim()) {
                $obj = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
                if ($null -ne $obj -and $obj.GetType() -eq [System.Management.Automation.PSCustomObject]) {
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
                            $entry = New-WinstCacheIndexEntryFromDir -Dir (Join-WinstPath $PkgDir $id)
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
            # （而不是文件真坏了），还能照着重找回来；仅内容相同才复用已有备份。
            try {
                $backup = $path + '.bak'
                Assert-WinstSafeWritePath -Path $path
                Assert-WinstSafeWritePath -Path $backup
                $originalHash = Get-WinstFileHash -Path $path
                if (-not $originalHash) { throw '无法读取损坏索引的原始内容' }
                $needCopy = $originalHash -cne (Get-WinstFileHash -Path $backup)
                if ($needCopy) { Copy-Item -LiteralPath $path -Destination $backup -Force -ErrorAction Stop }
                if ($originalHash -cne (Get-WinstFileHash -Path $backup)) { throw '备份内容与原索引不一致' }
            } catch {
                $result.CanSave = $false
                $result.BackupError = ('备份损坏索引失败，禁止覆盖原文件 {0}：{1}' -f $path, $_.Exception.Message)
                $result.Error += ' ' + $result.BackupError
            }
        }
    }

    # 索引里指向已不存在目录的条目：清除（下次写入时一并落盘）
    foreach ($id in @($result.Index.Keys)) {
        $dir = Join-WinstPath $PkgDir $id
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

    # 缓存里存副本：调用方（Update-WinstPackageCacheIndex）会就地改 Index 再写盘，
    # 存本体等于把「还没落盘的改动」留在缓存里，写盘失败后本进程会一直读到一份从未存在的索引。
    $cacheCopy = @{
        Rebuilt = [bool]$result.Rebuilt
        Changed = [bool]$result.Changed
        Error   = [string]$result.Error
        CanSave = [bool]$result.CanSave
        BackupError = [string]$result.BackupError
        Index   = (New-WinstOrdinalDictionary)
    }
    foreach ($id in @($result.Index.Keys)) {
        $cacheCopy.Index[$id] = Copy-WinstObjectShallow -InputObject $result.Index[$id]
    }
    (Get-WinstState -Name WinstJsonCache)[$cacheKey] = @{ Stamp = $indexFileStamp; Value = $cacheCopy; Raw = '' }
    return $result
}
