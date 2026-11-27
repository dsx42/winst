#Requires -Version 5.1

function Write-WinstInstalledState {
    param([string]$InstallRoot, $Installed, $Normalized, [string]$UpdatedId, $UpdatedEntry)
    $obj = [ordered]@{
        schemaVersion = (Get-WinstStateSchemaVersion)
        installed     = $installed
    }
    $path = Get-WinstStatePath -InstallRoot $InstallRoot
    Write-FileAtomic -Path $path -Content (ConvertTo-WinstJson -InputObject $obj -Depth 12)

    # 安装或卸载会改变系统状态，后续查询需要重新读取。
    Reset-WinstSystemCache

    # 刷新读缓存：内容就是刚落盘这一份（文件戳重新取，与磁盘一致）。
    # 迁移标记随本次保存一并落盘，因此不保留 NeedSave。
    # 单条更新沿用私有快照里的其他记录，仅替换写入缓存的已校验条目。
    if ($UpdatedId) { $Normalized[$UpdatedId] = $UpdatedEntry }
    $cache = Get-WinstState -Name WinstStateReadCache
    if ($null -ne $cache) {
        $stamp = Get-WinstFileStamp -Path $path
        if ($stamp) {
            $cache[$path] = @{
                Stamp    = $stamp
                State    = @{ SchemaVersion = (Get-WinstStateSchemaVersion); Installed = $normalized }
                NeedSave = $false
            }
        } else {
            $cache.Remove($path)
        }
    }
}
