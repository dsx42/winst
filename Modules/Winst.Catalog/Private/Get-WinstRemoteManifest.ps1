#Requires -Version 5.1

function Get-WinstRemoteManifest {
    <#
    .SYNOPSIS
        远程清单：固定 URL 直接下载；含 {version} 的先取指示地址，高于缓存版本（或 -Force）才重新下载。
    .DESCRIPTION
        内容不是合法 JSON / 为空时同样返回失败（并提示已保留既有缓存），由调用方决定是否中止刷新。
    .OUTPUTS
        同 Get-WinstManifestPayload
    #>
    param([hashtable]$Context, [string]$Url, [string]$CachePath, [switch]$HasCache, [string]$CachedVersion, [switch]$Force)

    $out = @{
        Ok = $false; Message = ''; Network = $false; Content = ''; Entries = @(); TargetUrl = $Url
        ManifestVersion = ''; ReusedFromCache = $false; WriteCache = $false; Files = @()
    }

    $isPlaceholder = $Url.Contains('{version}')
    $latest = ''
    $reusedFromCache = $false
    $targetUrl = $Url

    if ($isPlaceholder) {
        $indicatorUrl = $Url.Replace('{version}', 'latest')
        try {
            $indicatorText = Invoke-WinstHttpGet -Uri $indicatorUrl -Context $Context -NoCache
        } catch {
            $out.Network = $true
            $out.Message = ('探测最新版本失败: {0}' -f $_.Exception.Message)
            if ($HasCache) { $out.Message += '（已保留并使用既有缓存）' }
            return $out
        }

        foreach ($line in ($indicatorText -split "`r?`n")) {
            $text = [string]$line
            if ($text -and $text.Trim()) { $latest = $text.Trim(); break }
        }
        if (-not $latest) {
            $out.Message = '版本指示地址返回内容为空，无法确定最新版本'
            if ($HasCache) { $out.Message += '（已保留并使用既有缓存）' }
            return $out
        }

        # 版本号会原样拼进清单地址：只接受字母 / 数字 / `.` `_` `+` `-`。
        # 否则返回内容里的 `../`、`?`、`@host` 能拼出越权路径或主机（路径穿越、SSRF）
        if ($latest -notmatch '^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$') {
            $out.Message = ('版本指示地址返回的内容不像版本号（含非法字符），已拒绝：{0}' -f $latest)
            if ($HasCache) { $out.Message += '（已保留并使用既有缓存）' }
            return $out
        }

        if (-not $Force -and $HasCache -and $CachedVersion -and (Compare-WinstVersion -A $latest -B $CachedVersion) -le 0) {
            # 清单文件无需重新下载，但仍重新解析（软件版本可能已前移）
            $latest = $CachedVersion
            $reusedFromCache = $true
        }

        $targetUrl = $Url.Replace('{version}', $latest)
    }

    $content = ''
    $writeCache = $false
    if ($reusedFromCache) {
        try {
            $content = Get-Content -LiteralPath $CachePath -Raw -Encoding UTF8
        } catch {
            $out.Message = ('读取清单缓存失败: {0}' -f $_.Exception.Message)
            return $out
        }
    } else {
        try {
            $content = Invoke-WinstHttpGet -Uri $targetUrl -Context $Context -NoCache
        } catch {
            $statusCode = 0
            try { $statusCode = [int]$_.Exception.Response.StatusCode } catch { $statusCode = 0 }
            if ($statusCode -eq 404 -or $statusCode -eq 410) {
                $out.Message = ('清单文件不存在（HTTP {0}）: {1}；请确认仓库根目录有 manifest.json，或改用仓库内清单文件的完整地址' -f $statusCode, $targetUrl)
            } else {
                $out.Network = $true
                $out.Message = ('下载清单失败: {0}' -f $_.Exception.Message)
            }
            if ($HasCache) { $out.Message += '（已保留并使用既有缓存）' }
            return $out
        }
        $writeCache = $true
    }

    $obj = $null
    try {
        $obj = $content | ConvertFrom-Json
    } catch {
        $out.Message = ('清单内容不是合法 JSON: {0}' -f $_.Exception.Message)
        if ($HasCache) { $out.Message += '（已保留并使用既有缓存）' }
        return $out
    }

    # 内容为空（或仅空白 / 仅空数组）时 ConvertFrom-Json 不产生对象，需显式判空后再取属性
    if ($null -eq $obj) {
        $out.Message = '清单内容为空，不是有效的清单文件'
        if ($HasCache) { $out.Message += '（已保留并使用既有缓存）' }
        return $out
    }

    $manifestVersion = ''
    $prop = $obj.PSObject.Properties['_manifestVersion']
    if ($prop -and $null -ne $prop.Value) { $manifestVersion = ([string]$prop.Value).Trim() }
    if ($isPlaceholder -and -not $manifestVersion) { $manifestVersion = $latest }

    $out.Ok = $true
    $out.Content = [string]$content
    $out.Entries = @(Get-ManifestEntries -Manifest $obj)
    $out.TargetUrl = $targetUrl
    $out.ManifestVersion = $manifestVersion
    $out.ReusedFromCache = $reusedFromCache
    $out.WriteCache = $writeCache
    return $out
}
