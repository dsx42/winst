#Requires -Version 5.1

function Select-WinstBundleList {
    <#
    .SYNOPSIS
        ① 选择并加载安装清单（含来源缓存索引），失败 / 取消时打印原因。
    .OUTPUTS
        @{ Ok; Cancelled; ListPath; Loaded; SourceCacheIndex }
    #>
    param([hashtable]$Context, [string]$ListPath = '')

    if (-not $ListPath) {
        # 只挑现成清单：打包不提供「输入文件名新建」（新建请到「高级功能 → 管理安装清单」）
        $picked = Select-WinstListFile -Context $Context -NoCreate
        if (-not $picked.Ok) {
            Write-Host ''
            if ($picked.Cancelled) {
                return @{ Ok = $false; Cancelled = $true; ListPath = ''; Loaded = $null; SourceCacheIndex = $null }
            }
            Write-Host ('  {0}' -f $picked.Error) -ForegroundColor Red
            return @{ Ok = $false; Cancelled = $false; ListPath = ''; Loaded = $null; SourceCacheIndex = $null }
        }
        $ListPath = [string]$picked.Path
    } else {
        $resolved = Resolve-WinstListPath -Context $Context -Text $ListPath
        if (-not $resolved.Ok) {
            Write-Host ''
            Write-Host ('  {0}' -f $resolved.Error) -ForegroundColor Red
            return @{ Ok = $false; Cancelled = $false; ListPath = ''; Loaded = $null; SourceCacheIndex = $null }
        }
        $ListPath = $resolved.Path
    }

    $loaded = Get-WinstListItems -Context $Context -Path $ListPath
    if (-not $loaded.Ok) {
        Write-Host ''
        Write-Host ('  {0}' -f $loaded.Error) -ForegroundColor Red
        return @{ Ok = $false; Cancelled = $false; ListPath = $ListPath; Loaded = $null; SourceCacheIndex = $null }
    }
    if ($loaded.Warning) { Write-Host ('  提示: {0}' -f $loaded.Warning) -ForegroundColor DarkYellow }
    if (-not $loaded.Exists -or @($loaded.Items).Count -eq 0) {
        Write-Host ''
        Write-Host '  这份安装清单是空的。' -ForegroundColor Yellow
        Write-Host ('  清单文件: {0}' -f $ListPath) -ForegroundColor DarkGray
        Write-Host '  请先到「高级功能 → 管理安装清单」里新建或编辑清单，挑选软件。' -ForegroundColor DarkGray
        return @{ Ok = $false; Cancelled = $false; ListPath = $ListPath; Loaded = $null; SourceCacheIndex = $null }
    }

    # 来源缓存索引：复制包文件时把它的摘要 / 文件元数据一并带进套件索引（取不到就按空处理，见下）
    $sourceCacheIndex = $null
    if ($loaded.Lookup -and [bool]$loaded.Lookup['Ok'] -and $loaded.Lookup['CacheIndex']) { $sourceCacheIndex = $loaded.Lookup['CacheIndex'] }

    return @{ Ok = $true; Cancelled = $false; ListPath = $ListPath; Loaded = $loaded; SourceCacheIndex = $sourceCacheIndex }
}
