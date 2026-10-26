#Requires -Version 5.1

function Save-WinstState {
    <#
    .SYNOPSIS
        原子写入安装台账（<安装根目录>\state.json；UTF-8 无 BOM；schemaVersion 2）。
    .DESCRIPTION
        写完立即用**刚写入的内容**刷新台账读缓存，而不是简单清空：
        清空会让紧随其后的读重新解析一遍（写入后几乎总要再读一次），
        直接刷新则让「写完再读」保持缓存命中。外部改动仍由文件戳兜底。

        失效范围按「谁真的依赖台账」划定：注册表卸载项、Appx 包、环境变量、引擎路径
        都以台账 / 系统安装状态为依据，必须重读；而**进程快照**只反映「当前有哪些进程」
        （另有 3 秒 TTL 自管），**本地清单文件列表**只反映脚本目录与 pkgDir 下的文件，
        两者都与台账内容无关，不随台账变化失效——否则写一次台账就要重新枚举一次
        全部进程（实测冷启动约 1.1 秒），把「写台账」变成整条流程里最贵的一步。
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

    # 台账变化意味着本机可能刚装 / 刚卸了软件：注册表卸载项、Appx 包、环境变量、引擎路径
    # 都要重读（不带 -All：进程快照与本地清单文件列表不受台账影响，见函数说明）。
    # 这一步必须在写缓存**之前**：它不会清台账读缓存，但保持「先失效、后刷新」的顺序更稳。
    Reset-WinstSystemCache

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
