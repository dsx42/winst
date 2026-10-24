#Requires -Version 5.1

function Get-WinstRemoteValidators {
    <#
    .SYNOPSIS
        发一次 HEAD 取远端文件的校验器（ETag / Last-Modified / Content-Length），供 files[].refresh 判定使用。
    .OUTPUTS
        @{ Ok; ETag; LastModified; Size; Error }
    .DESCRIPTION
        元数据类请求：与 HEAD 可用性探测共用「直连 → 代理重试」链，并把结果按 URL 记入进程内
        TTL 缓存——同一批安装 / 更新里同一个地址只请求一次。
        站点不支持 HEAD、超时、代理失败、4xx/5xx 时 Ok = $false 并给出原因；**这一点不视为失败**：
        调用方按 8.4 的兜底策略继续（check 按重取处理、其余退到 TTL 兜底），不否定缓存（见 12）。
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Uri,
        [int]$TimeoutSec = 20
    )

    $result = @{ Ok = $false; ETag = ''; LastModified = ''; Size = $null; Error = '' }
    if (-not $Uri) { $result.Error = '缺少地址'; return $result }

    if (-not (Get-WinstState -Name WinstHttpCache)) {
        $null = Set-WinstState -Name WinstHttpCache -Value (New-Object 'System.Collections.Hashtable' ([StringComparer]::Ordinal))
    }
    $cacheKey = 'validators|' + $Uri
    if ((Get-WinstState -Name WinstHttpCache).ContainsKey($cacheKey)) {
        $cachedItem = (Get-WinstState -Name WinstHttpCache)[$cacheKey]
        $age = ([DateTime]::Now - [DateTime]$cachedItem['At']).TotalSeconds
        if ($age -le (Get-WinstHttpCacheTtlSec)) { return $cachedItem['Value'] }
        (Get-WinstState -Name WinstHttpCache).Remove($cacheKey)
    }

    $attempts = @(Get-WinstProxyAttempts -Context $Context)
    $lastError = ''
    foreach ($currentProxy in $attempts) {
        try {
            $params = @{
                Uri             = $Uri
                Method          = 'Head'
                UseBasicParsing = $true
                TimeoutSec      = $TimeoutSec
                Headers         = (Get-WinstBrowserHeaders)
            }
            if ($currentProxy) { $params['Proxy'] = $currentProxy }
            $response = Invoke-WebRequest @params

            $etag = ''
            $lastModified = ''
            $size = $null
            $headers = $null
            try { $headers = $response.Headers } catch { $headers = $null }
            if ($headers) {
                foreach ($key in @($headers.Keys)) {
                    $text = ([string]$headers[$key]).Trim()
                    if ([string]$key -ieq 'ETag') { $etag = $text }
                    elseif ([string]$key -ieq 'Last-Modified') { $lastModified = $text }
                    elseif ([string]$key -ieq 'Content-Length') {
                        $length = 0L
                        if ([long]::TryParse($text, [ref]$length)) { $size = $length }
                    }
                }
            }

            $result.Ok = $true
            $result.ETag = $etag
            $result.LastModified = $lastModified
            $result.Size = $size
            $lastError = ''
            break
        } catch {
            $lastError = $_.Exception.Message
        }
    }

    if (-not $result.Ok) { $result.Error = $lastError }
    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
        $note = '失败：' + $result.Error
        if ($result.Ok) {
            $etagText = '无'
            if ($result.ETag) { $etagText = $result.ETag }
            $modifiedText = '无'
            if ($result.LastModified) { $modifiedText = $result.LastModified }
            $sizeText = '无'
            if ($null -ne $result.Size) { $sizeText = [string]$result.Size }
            $note = ('ETag {0} / Last-Modified {1} / 长度 {2}' -f $etagText, $modifiedText, $sizeText)
        }
        Write-Host ('  [verbose] 确认远端文件是否变化 {0} → {1}' -f $Uri, $note) -ForegroundColor DarkGray
    }

    (Get-WinstState -Name WinstHttpCache)[$cacheKey] = @{ At = [DateTime]::Now; Value = $result }
    return $result
}
