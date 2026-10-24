#Requires -Version 5.1

function Save-WinstState {
    <#
    .SYNOPSIS
        原子写入安装台账（<安装根目录>\state.json；UTF-8 无 BOM；schemaVersion 2）。
    .DESCRIPTION
        写完立即用**刚写入的内容**刷新台账读缓存，而不是简单清空：
        清空会让紧随其后的读重新解析一遍（写入后几乎总要再读一次），
        直接刷新则让「写完再读」保持缓存命中。外部改动仍由文件戳兜底。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$InstallRoot,
        [Parameter(Mandatory = $true)][hashtable]$State
    )

    $installed = $State['Installed']
    if ($null -eq $installed) { $installed = (New-WinstOrdinalDictionary) }

    $obj = [ordered]@{
        schemaVersion = (Get-WinstStateSchemaVersion)
        installed     = $installed
    }
    $path = Get-WinstStatePath -InstallRoot $InstallRoot
    Write-FileAtomic -Path $path -Content (ConvertTo-WinstJson -InputObject $obj -Depth 12)

    # 台账变化意味着本机可能刚装 / 刚卸了软件：注册表卸载项、Appx 包、进程与引擎路径快照都要重读。
    # 这一步必须在写缓存**之前**：它会连台账读缓存一起清空（-All 的语义是「全部失效」）。
    Reset-WinstSystemCache -All

    # 刷新读缓存：内容就是刚落盘这一份（文件戳重新取，与磁盘一致）。
    # 迁移标记随本次保存一并落盘，因此不保留 NeedSave。
    # 存副本而不是 $installed 本身：调用方常常在保存后继续就地修改手里的对象
    # （再保存一次、或只改内存），缓存若持有同一引用就会跟着变，下次读到的将是未落盘的内容。
    $cache = Get-WinstState -Name WinstStateReadCache
    if ($null -ne $cache) {
        $stamp = Get-WinstFileStamp -Path $path
        if ($stamp) {
            $cache[$path] = @{
                Stamp    = $stamp
                State    = (Copy-WinstState -State @{ SchemaVersion = (Get-WinstStateSchemaVersion); Installed = $installed })
                Migrated = $false
                NeedSave = $false
            }
        } else {
            $cache.Remove($path)
        }
    }
}
