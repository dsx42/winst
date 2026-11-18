#Requires -Version 5.1

function Write-WinstInstalledState {
    param([string]$InstallRoot, $Installed, $Normalized, [string]$UpdatedId, $UpdatedEntry)
    $obj = [ordered]@{
        schemaVersion = (Get-WinstStateSchemaVersion)
        installed     = $installed
    }
    $path = Get-WinstStatePath -InstallRoot $InstallRoot
    Write-FileAtomic -Path $path -Content (ConvertTo-WinstJson -InputObject $obj -Depth 12)

    # 台账变化意味着本机可能刚装 / 刚卸了软件：注册表卸载项、Appx 包、环境变量、引擎路径
    # 都要重读（不带 -All：进程快照与本地清单文件列表不受台账影响，见函数说明）。
    # 这一步必须在写缓存**之前**：它不会清台账读缓存，但保持「先失效、后刷新」的顺序更稳。
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
                Migrated = $false
                NeedSave = $false
            }
        } else {
            $cache.Remove($path)
        }
    }
}
