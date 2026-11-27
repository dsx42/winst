#Requires -Version 5.1

function Read-WinstState {
    <#
    .SYNOPSIS
        读取安装台账；缺失 / 损坏 / 低版本分别按「新建 / 备份重建 / 迁移」处理。
    .OUTPUTS
        @{ State; Reset; NeedSave; Error }
    .DESCRIPTION
        台账位于 <安装根目录>\state.json；解析失败 → 备份为 state.json.bak-<时间戳> 并重建空台账；
        备份本身失败时**停止写入**（Reset / NeedSave 均为 $false，Error 说明原因），避免空台账覆盖唯一副本。
        schemaVersion 缺失或低于当前 → 迁移补默认值并标记 NeedSave；高于当前 → Error 提示升级 winst。

        读缓存：解析 + 归一化的结果按「文件戳（最后写入时间 + 长度）」缓存在进程内，
        再次读取时，文件戳相同就返回缓存的副本。
        写入侧 Save-WinstState 会刷新缓存，因此「写完再读」立即看到新内容；
        文件被外部改动时文件戳变化，缓存自动失效，不依赖调用方手动清理。

        条目内的数组与嵌套字典按引用共享。命中缓存且指定 ForEntryReplacement 时，
        整个条目也按引用共享。修改台账须用 Set-WinstInstalledApp 整条替换。
    #>
    param([Parameter(Mandatory = $true)][string]$InstallRoot, [switch]$ForEntryReplacement, [string[]]$Ids)

    $selection = @{}
    if ($PSBoundParameters.ContainsKey('Ids')) { $selection['Ids'] = $Ids }
    $result = @{
        State      = (New-WinstState)
        Reset      = $false
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
                $result.State = (Copy-WinstState -State $cached['State'] -ShareEntries:$ForEntryReplacement @selection)
                $result.NeedSave = [bool]$cached['NeedSave']
                $result.Reset = [bool]$cached['Reset']
                $result.Error = [string]$cached['Error']
                return $result
            }
        }
    }

    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $result }

    try {
        $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    } catch {
        $result.Error = ('读取安装台账失败: {0}' -f $_.Exception.Message)
        return $result
    }

    try {
        $obj = $raw | ConvertFrom-Json
    } catch {
        $obj = $null
    }

    if ($obj -isnot [System.Management.Automation.PSCustomObject]) {
        $stampText = (Get-Date).ToString('yyyyMMdd-HHmmss')
        $backup = '{0}.bak-{1}-{2}' -f $path, $stampText, ([guid]::NewGuid().ToString('N').Substring(0, 8))
        try {
            Assert-WinstSafeWritePath -Path $backup
            Copy-Item -LiteralPath $path -Destination $backup -Force -ErrorAction Stop
        } catch {
            # 备份失败时不得重建：调用方普遍以 -not $Reset 判错，一旦允许继续，
            # 后续任何一次 Save-WinstState 都会用空台账覆盖唯一副本 → 安装记录全丢。
            $result.Error = ('安装台账无法解析且备份失败，已停止写入以免丢数据：{0}' -f $_.Exception.Message)
            return $result
        }
        $result.Reset = $true
        $result.NeedSave = $true
        $result.Error = ('安装台账无法解析，已重建空台账（原文件备份为 {0}）' -f (Split-Path -Leaf $backup))
        if ($stamp) {
            (Get-WinstState -Name WinstStateReadCache)[$path] = @{
                Stamp = $stamp; State = (Copy-WinstState -State $result.State)
                NeedSave = $true; Reset = $true
                Error = $result.Error
            }
        }
        return $result
    }

    $version = 0
    $vp = $obj.PSObject.Properties['schemaVersion']
    if ($vp -and $null -ne $vp.Value) {
        $parsed = 0
        if ([int]::TryParse((ConvertTo-WinstTextValue -Value $vp.Value), [ref]$parsed)) { $version = $parsed }
    }

    if ($version -gt (Get-WinstStateSchemaVersion)) {
        $result.Error = ('安装台账版本（{0}）高于当前 winst 支持的版本（{1}），请升级 winst 后再试。' -f $version, (Get-WinstStateSchemaVersion))
        return $result
    }

    if ($version -lt (Get-WinstStateSchemaVersion)) {
        $result.NeedSave = $true
    }

    $installed = New-WinstOrdinalDictionary
    $ip = $obj.PSObject.Properties['installed']
    # installed 必须是「id → 条目」的字典 / 对象。写成数组或字符串时，PSObject.Properties
    # 会暴露 Length / Count / Rank 这类成员，它们会被当成软件 id 写进台账并整份落盘。
    $installedShapeOk = ($null -eq $ip) -or ($null -eq $ip.Value) -or
        ($ip.Value -is [System.Management.Automation.PSCustomObject])
    if (-not $installedShapeOk) {
        $result.Error = '安装台账里的 installed 不是「id → 条目」结构，已停止写入以免覆盖原记录；请人工检查 state.json'
        $result.NeedSave = $false
        return $result
    }
    if ($ip -and $null -ne $ip.Value) {
        # 直接逐条归一化写入台账，不先复制进中转数组
        foreach ($prop in $ip.Value.PSObject.Properties) {
            $id = [string]$prop.Name
            if (-not $id) { continue }
            try { $installed[$id] = (ConvertTo-WinstInstalledEntry -Entry $prop.Value) }
            catch { $result.Error += ('安装条目 {0} 无效：{1}。' -f $id, $_.Exception.Message) }
        }
    }

    $result.State = @{ SchemaVersion = (Get-WinstStateSchemaVersion); Installed = $installed }
    if ($result.Error) { $result.NeedSave = $false; return $result }

    # —— 写入读缓存（缓存归一化结果；NeedSave 一并记住，命中时行为与首次一致） ——
    # 缓存单独的条目字典，以便调用方替换整条记录。
    if ($stamp) {
        $cache = Get-WinstState -Name WinstStateReadCache
        if ($null -ne $cache) {
            $cache[$path] = @{
                Stamp    = $stamp
                State    = (Copy-WinstState -State $result.State)
                NeedSave = [bool]$result.NeedSave
            }
        }
    }

    if ($selection.Count) { $result.State = Copy-WinstState -State $result.State @selection }
    return $result
}
