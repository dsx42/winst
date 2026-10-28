#Requires -Version 5.1

function Read-WinstState {
    <#
    .SYNOPSIS
        读取安装台账；缺失 / 损坏 / 低版本分别按「新建 / 备份重建 / 迁移」处理。
    .OUTPUTS
        @{ State; Migrated; Reset; BackupPath; NeedSave; Error }
    .DESCRIPTION
        台账位于 <安装根目录>\state.json；解析失败 → 备份为 state.json.bak-<时间戳> 并重建空台账；
        备份本身失败时**停止写入**（Reset / NeedSave 均为 $false，Error 说明原因），避免空台账覆盖唯一副本。
        schemaVersion 缺失或低于当前 → 迁移补默认值并标记 NeedSave；高于当前 → Error 提示升级 winst。

        读缓存：解析 + 归一化的结果按「文件戳（最后写入时间 + 长度）」缓存在进程内，
        同一份文件重复读取只做一次 stat 后直接返回副本。台账在一次操作里会被反复读
        （列表页每个条目、每条新鲜度提示、每次引擎定位各读一次），而一次完整解析在
        几十条记录时是百毫秒级，缓存后降到亚毫秒。
        写入侧 Save-WinstState 会刷新缓存，因此「写完再读」立即看到新内容；
        文件被外部改动时文件戳变化，缓存自动失效，不依赖调用方手动清理。

        返回的是**副本**（见 Copy-WinstState）：调用方可以就地修改条目，
        缓存不被污染；要不要落盘只由 Save-WinstState 决定。
    #>
    param([Parameter(Mandatory = $true)][string]$InstallRoot)

    $result = @{
        State      = (New-WinstState)
        Migrated   = $false
        Reset      = $false
        BackupPath = ''
        NeedSave   = $false
        Error      = ''
    }

    $path = Get-WinstStatePath -InstallRoot $InstallRoot

    # —— 读缓存命中：只做一次文件戳比对 ——
    $stamp = Get-WinstFileStamp -Path $path
    if ($stamp) {
        $cache = Get-WinstState -Name WinstStateReadCache
        if ($null -ne $cache -and $cache.ContainsKey($path)) {
            $cached = $cache[$path]
            if ([string]$cached['Stamp'] -eq $stamp) {
                $result.State = (Copy-WinstState -State $cached['State'])
                $result.Migrated = [bool]$cached['Migrated']
                $result.NeedSave = [bool]$cached['NeedSave']
                return $result
            }
        }
    }

    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $result }

    $raw = ''
    try {
        $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    } catch {
        $result.Error = ('读取安装台账失败: {0}' -f $_.Exception.Message)
        return $result
    }
    if (-not $raw -or -not $raw.Trim()) { return $result }

    $obj = $null
    try {
        $obj = $raw | ConvertFrom-Json
    } catch {
        $obj = $null
    }

    if ($null -eq $obj) {
        $stampText = (Get-Date).ToString('yyyyMMdd-HHmmss')
        $backup = '{0}.bak-{1}' -f $path, $stampText
        try {
            Copy-Item -LiteralPath $path -Destination $backup -Force -ErrorAction Stop
            $result.BackupPath = $backup
        } catch {
            # 备份失败时不得重建：调用方普遍以 -not $Reset 判错，一旦允许继续，
            # 后续任何一次 Save-WinstState 都会用空台账覆盖唯一副本 → 安装记录全丢。
            $result.BackupPath = ''
            $result.Reset = $false
            $result.NeedSave = $false
            $result.Error = ('安装台账无法解析且备份失败，已停止写入以免丢数据：{0}' -f $_.Exception.Message)
            return $result
        }
        $result.Reset = $true
        $result.NeedSave = $true
        $result.Error = ('安装台账无法解析，已重建空台账（原文件备份为 {0}）' -f (Split-Path -Leaf $backup))
        return $result
    }

    $version = 0
    $versionValue = $null
    if ($obj -is [System.Collections.IDictionary]) {
        if ($obj.Contains('schemaVersion')) { $versionValue = $obj['schemaVersion'] }
    } else {
        $vp = $obj.PSObject.Properties['schemaVersion']
        if ($vp) { $versionValue = $vp.Value }
    }
    if ($null -ne $versionValue) {
        $parsed = 0
        if ([int]::TryParse((ConvertTo-WinstTextValue -Value $versionValue), [ref]$parsed)) { $version = $parsed }
    }

    if ($version -gt (Get-WinstStateSchemaVersion)) {
        $result.Error = ('安装台账版本（{0}）高于当前 winst 支持的版本（{1}），请升级 winst 后再试。' -f $version, (Get-WinstStateSchemaVersion))
        return $result
    }

    if ($version -lt (Get-WinstStateSchemaVersion)) {
        $result.Migrated = $true
        $result.NeedSave = $true
    }

    $installed = New-WinstOrdinalDictionary
    $ip = $obj.PSObject.Properties['installed']
    # installed 必须是「id → 条目」的字典 / 对象。写成数组或字符串时，PSObject.Properties
    # 会暴露 Length / Count / Rank 这类成员，它们会被当成软件 id 写进台账并整份落盘。
    $installedShapeOk = ($null -eq $ip) -or ($null -eq $ip.Value) -or
        ($ip.Value -is [System.Collections.IDictionary]) -or
        ($ip.Value -is [System.Management.Automation.PSCustomObject])
    if (-not $installedShapeOk) {
        $result.Error = '安装台账里的 installed 不是「id → 条目」结构，已停止写入以免覆盖原记录；请人工检查 state.json'
        $result.NeedSave = $false
        return $result
    }
    if ($ip -and $null -ne $ip.Value) {
        # 直接逐条归一化写入台账，不先复制进中转数组
        if ($ip.Value -is [System.Collections.IDictionary]) {
            foreach ($key in @($ip.Value.Keys)) {
                $id = [string]$key
                if (-not $id) { continue }
                $installed[$id] = (ConvertTo-WinstInstalledEntry -Entry $ip.Value[$key])
            }
        } else {
            foreach ($prop in $ip.Value.PSObject.Properties) {
                $id = [string]$prop.Name
                if (-not $id) { continue }
                $installed[$id] = (ConvertTo-WinstInstalledEntry -Entry $prop.Value)
            }
        }
    }

    $result.State = @{ SchemaVersion = (Get-WinstStateSchemaVersion); Installed = $installed }

    # —— 写入读缓存（缓存归一化结果；NeedSave / Migrated 一并记住，命中时行为与首次一致） ——
    # 存**副本**、返回原对象：缓存里的那份一旦被调用方就地改到（如 repair 更正版本、
    # 合并大小写重复 id），下一次读就会读到从未落盘的内容。热路径本来返回副本，
    # 这里存同一引用会让「冷路径改内存 = 改了缓存」，与文档承诺的「返回副本」相矛盾。
    if ($stamp) {
        $cache = Get-WinstState -Name WinstStateReadCache
        if ($null -ne $cache) {
            $cache[$path] = @{
                Stamp    = $stamp
                State    = (Copy-WinstState -State $result.State)
                Migrated = [bool]$result.Migrated
                NeedSave = [bool]$result.NeedSave
            }
        }
    }

    return $result
}
