#Requires -Version 5.1

function Save-WinstFileWithHttp {
    <#
    .SYNOPSIS
        下载引擎首次引导时，经指定连接将文件直接下载到本次暂存位置。
    #>
    param([uri]$Uri, [string]$OutFile, [hashtable]$Headers, [string]$ProxyUrl)

    $response = $null
    $file = $null
    $received = 0L
    $kind = 'Other'
    try {
        # PowerShell 5.1 的 IWR -OutFile 遇到响应提前结束也可能成功，需要核对同一响应的长度。
        $request = [Net.WebRequest]::Create($Uri)
        $request.Timeout = 900000
        if ($ProxyUrl) { $request.Proxy = New-Object Net.WebProxy($ProxyUrl) }
        if ($Headers['Referer']) { $request.Referer = $Headers['Referer'] }
        if ($Headers['User-Agent']) { $request.UserAgent = $Headers['User-Agent'] }
        if ($Headers['Cookie']) {
            $request.CookieContainer = New-Object Net.CookieContainer
            foreach ($pair in ($Headers['Cookie'] -split ';\s*')) {
                $parts = $pair -split '=', 2
                if ($parts.Count -ne 2) { throw '下载请求的 Cookie 格式无效' }
                $cookie = New-Object Net.Cookie($parts[0].Trim(), $parts[1], '/')
                $request.CookieContainer.Add($Uri, $cookie)
            }
        }
        $response = $request.GetResponse()
        $stream = $response.GetResponseStream()
        $kind = 'Disk'
        $file = [IO.File]::Open($OutFile, 'Create', 'Write', 'None')
        $buffer = New-Object byte[] 65536
        while ($true) {
            $kind = 'Other'
            if ($received -gt 0) { $kind = 'Interrupted' }
            $count = $stream.Read($buffer, 0, $buffer.Length)
            if ($count -eq 0) { break }
            $kind = 'Disk'
            $file.Write($buffer, 0, $count)
            $received += $count
        }
        if ($response.ContentLength -ge 0 -and $received -ne $response.ContentLength) {
            throw ('响应提前结束，收到 {0} 字节，预期 {1} 字节' -f $received, $response.ContentLength)
        }
        $kind = 'Disk'
        $file.Close()
        return @{ Ok = $true }
    } catch {
        $statusCode = 0
        $cause = $_.Exception
        while ($cause.InnerException -and $cause -isnot [Net.WebException]) { $cause = $cause.InnerException }
        if ($cause -is [Net.WebException]) {
            if ($cause.Response -is [Net.HttpWebResponse]) {
                $kind = 'Http'
                $statusCode = [int]$cause.Response.StatusCode
            }
            elseif ($cause.Status -in @('NameResolutionFailure', 'ProxyNameResolutionFailure', 'ConnectFailure', 'Timeout') -and $received -eq 0) { $kind = 'Connect' }
            if ($cause.Response) { $cause.Response.Close() }
        }
        return @{ Ok = $false; FailureKind = $kind; StatusCode = $statusCode; Error = $_.Exception.Message }
    } finally {
        if ($file) { $file.Dispose() }
        if ($response) { $response.Close() }
    }
}
