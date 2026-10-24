#Requires -Version 5.1

function Test-RemoteFileExists {
    <#
    .SYNOPSIS
        探测远程文件是否存在（HEAD 请求）。
    .OUTPUTS
        $true（存在）/ $false（确认不存在：404 / 410，或重定向后最终地址不包含 FinalUriMustContain）/
        $null（无法判断：网络失败或服务器不支持 HEAD）
    .DESCRIPTION
        用于校验解析出的安装包地址是否真的可以下载（历史问题：版本列表页会提前出现尚未发布正式包的版本目录，
        如 python.org 的 3.15.0 目录此时只有 alpha 包）。代理行为与其它元数据请求一致，结果按 URL、完整请求头
        与最终地址校验条件记入进程内 TTL 缓存，相同请求不重复探测。
        FinalUriMustContain：传入版本号时，200 还要再核对「重定向后的最终地址仍然包含它」——部分站点
        （如 SourceForge 的 /download）对不存在的文件不回 404，而是 302 回项目文件根目录并返回 200 的
        HTML 错误页，只看状态码会误判成存在。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [hashtable]$Context,
        [int]$TimeoutSec = 20,
        [hashtable]$Headers = $null,
        [string]$FinalUriMustContain = ''
    )

    if (-not (Get-WinstState -Name WinstHttpCache)) {
        $null = Set-WinstState -Name WinstHttpCache -Value (New-Object 'System.Collections.Hashtable' ([StringComparer]::Ordinal))
    }

    # 缓存键同时体现完整请求头与最终地址校验条件，避免同一 URL 的不同请求共用结果。
    $cacheKey = 'probe|' + (Get-WinstHttpCacheKey -Uri $Uri -Headers $Headers -Method 'Head')
    if ($FinalUriMustContain) { $cacheKey += ('|seg:' + $FinalUriMustContain) }
    if ((Get-WinstState -Name WinstHttpCache).ContainsKey($cacheKey)) {
        $cachedItem = (Get-WinstState -Name WinstHttpCache)[$cacheKey]
        $age = ([DateTime]::Now - [DateTime]$cachedItem['At']).TotalSeconds
        if ($age -le (Get-WinstHttpCacheTtlSec)) { return $cachedItem['Exists'] }
        (Get-WinstState -Name WinstHttpCache).Remove($cacheKey)
    }

    $attempts = @(Get-WinstProxyAttempts -Context $Context)

    $exists = $null
    foreach ($currentProxy in $attempts) {
        try {
            $params = @{
                Uri             = $Uri
                Method          = 'Head'
                UseBasicParsing = $true
                TimeoutSec      = $TimeoutSec
            }
            if ($currentProxy) { $params['Proxy'] = $currentProxy }
            if ($Headers -and $Headers.Count -gt 0) { $params['Headers'] = $Headers }
            $resp = Invoke-WebRequest @params
            $exists = $true
            # 200 ≠ 存在：SourceForge 的 /download 对不存在的文件 302 回项目文件根目录（200 的 HTML
            # 错误页）。声明了 FinalUriMustContain 时核对最终地址仍包含该段，否则按不存在处理，
            # 让调用方继续尝试下一个候选（版本号从 URL 上取，重定向后的镜像地址仍带着它）
            if ($FinalUriMustContain) {
                $finalText = ''
                try { $finalText = [string]$resp.BaseResponse.ResponseUri } catch { }
                if (-not $finalText) { try { $finalText = [string]$resp.BaseResponse.RequestMessage.RequestUri } catch { } }
                if ($finalText -and ($finalText -notlike ('*' + $FinalUriMustContain + '*'))) { $exists = $false }
            }
        } catch {
            $statusCode = 0
            $response = $null
            try { $response = $_.Exception.Response } catch { $response = $null }
            if ($null -ne $response) {
                try { $statusCode = [int]$response.StatusCode } catch { $statusCode = 0 }
            }
            if ($statusCode -eq 404 -or $statusCode -eq 410) {
                $exists = $false
            } else {
                # 其它错误（网络故障、代理问题、服务器不支持 HEAD 等）：无法判断
                $exists = $null
            }
        }
        if ($null -ne $exists) { break }
    }

    if ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
        Write-Host ('  [verbose] 校验安装包地址 {0} → {1}' -f $Uri, $(if ($null -eq $exists) { '无法判断' } elseif ($exists) { '存在' } else { '不存在' })) -ForegroundColor DarkGray
    }

    (Get-WinstState -Name WinstHttpCache)[$cacheKey] = @{ At = [DateTime]::Now; Exists = $exists }
    return $exists
}
