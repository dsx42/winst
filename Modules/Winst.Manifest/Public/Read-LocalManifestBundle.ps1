#Requires -Version 5.1

function Read-LocalManifestBundle {
    <#
    .SYNOPSIS
        读取并合并本地清单文件（脚本同目录 manifest.json / manifests\*.json、安装包位置 manifests\*.json）。
    .DESCRIPTION
        按探测顺序依次读入，同一来源内同 id 取先出现者（重复的 id 忽略并提示）；清单版本取各文件中最高者，
        更新时间取各文件修改时间中最新者。任一文件读取 / 解析失败即整体失败——本地清单是手写文件，
        出错要让用户直接看到。
    .OUTPUTS
        @{ Entries; Version; FetchedAt; Error; Notes }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Source
    )

    $result = @{ Entries = @(); Version = ''; FetchedAt = ''; Error = ''; Notes = @() }
    $files = @(Get-EntryArray -Entry $Source -Key 'files')
    if ($files.Count -eq 0) {
        $result.Error = '没有找到本地清单文件'
        return $result
    }

    $seen = New-Object 'System.Collections.Hashtable' ([StringComparer]::Ordinal)
    $entries = New-Object 'System.Collections.Generic.List[object]'

    foreach ($item in $files) {
        $filePath = [string]$item
        if (-not $filePath) { continue }
        $fileName = ''
        try { $fileName = Split-Path -Leaf $filePath } catch { $fileName = $filePath }

        # 按文件缓存解析结果：本地清单在一次会话里会被反复汇总（搜索 / 依赖索引 / 刷新都会读）
        $read = Read-WinstJsonFileCached -Path $filePath
        if (-not $read.Ok) {
            $result.Error = ('读取本地清单失败: {0}（{1}）（清单文件一律使用 UTF-8 编码）' -f $filePath, $read.Error)
            return $result
        }
        $obj = $read.Value
        if ($null -eq $obj) { continue }

        $fileVersion = Get-EntryString -Entry $obj -Key '_manifestVersion'
        if ($fileVersion -and (-not $result.Version -or (Compare-WinstVersion -A $fileVersion -B $result.Version) -gt 0)) {
            $result.Version = $fileVersion
        }

        $stamp = (Get-Date).ToString('s')
        try { $stamp = (Get-Item -LiteralPath $filePath).LastWriteTime.ToString('s') } catch { }
        if (-not $result.FetchedAt -or $stamp -gt $result.FetchedAt) { $result.FetchedAt = $stamp }

        foreach ($entry in @(Get-ManifestEntries -Manifest $obj)) {
            $id = Get-EntryString -Entry $entry -Key 'id'
            if (-not $id) {
                $result.Notes += ('{0} 里有一条没有写 id 的软件定义，已忽略' -f $fileName)
                continue
            }
            if ($seen.ContainsKey($id)) {
                $result.Notes += ('{0} 里的 "{1}" 在前面已经出现过，已按先出现的定义为准' -f $fileName, $id)
                continue
            }
            $seen[$id] = $true
            $entries.Add($entry)
        }
    }

    $result.Entries = @($entries.ToArray())
    return $result
}
