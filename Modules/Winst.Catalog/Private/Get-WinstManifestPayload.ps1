#Requires -Version 5.1

function Get-WinstManifestPayload {
    <#
    .SYNOPSIS
        取得清单内容与条目：本地清单直接读文件，远程按 {version} 指示地址 / 缓存复用决定是否下载。
    .OUTPUTS
        @{ Ok; Message; Network; Content; Entries; TargetUrl; ManifestVersion; ReusedFromCache; WriteCache; Files }
    #>
    param([hashtable]$Context, $Source, [string]$Name, [string]$Url, [switch]$IsLocal,
        [string]$CachePath, [switch]$HasCache, [string]$CachedVersion, [switch]$Force)

    $out = @{
        Ok = $false; Message = ''; Network = $false; Content = ''; Entries = @(); TargetUrl = $Url
        ManifestVersion = ''; ReusedFromCache = $false; WriteCache = $false; Files = @()
    }

    if ($IsLocal) {
        $local = Read-LocalManifestBundle -Context $Context -Source $Source
        foreach ($note in @($local.Notes)) {
            Write-Host ('  提示: {0}' -f $note) -ForegroundColor DarkYellow
        }
        if ($local.Error) {
            $out.Message = [string]$local.Error
            return $out
        }
        $out.Ok = $true
        $out.Entries = @($local.Entries)
        if ($local.Version) { $out.ManifestVersion = [string]$local.Version }
        # 更新时间 = 本次刷新的时刻（每次刷新都改写，便于多机共用安装包位置时确认谁刷新过）
        $out.TargetUrl = (@(Get-EntryArray -Entry $Source -Key 'files') -join ' ; ')
        $out.Files = @(Get-EntryArray -Entry $Source -Key 'files')
        return $out
    }

    return (Get-WinstRemoteManifest -Context $Context -Url $Url -CachePath $CachePath -HasCache:$HasCache `
            -CachedVersion $CachedVersion -Force:$Force)
}
