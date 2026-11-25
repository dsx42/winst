#Requires -Version 5.1

function Invoke-WinstFluxApi {
    param([hashtable]$Service, [string]$Method, [string]$Route, [hashtable]$Body, [switch]$Reconnect)

    for ($attempt = 0; ; $attempt++) {
        $request = [Net.HttpWebRequest]::Create($Service.Address + '/api/v1/' + $Route)
        $request.Method = $Method
        $request.Proxy = $null
        $request.AllowAutoRedirect = $false
        $request.Timeout = 5000
        $request.ReadWriteTimeout = 5000
        try { $request.Headers['Authorization'] = 'Bearer ' + ([Net.NetworkCredential]::new('', $Service.Token)).Password }
        catch { throw 'FluxDown Token 无法用于请求鉴权' }
        try {
            if ($Body) {
                $data = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json -InputObject $Body -Depth 8 -Compress))
                $request.ContentType = 'application/json'
                $request.ContentLength = $data.Length
                $output = $request.GetRequestStream()
                try { $output.Write($data, 0, $data.Length) } finally { $output.Dispose() }
            }
            $response = $request.GetResponse()
            try {
                if ([int]$response.StatusCode -ne 200) { throw '管理接口未返回成功响应' }
                $reader = New-Object IO.StreamReader($response.GetResponseStream(), [Text.Encoding]::UTF8)
                try { return ($reader.ReadToEnd() | ConvertFrom-Json -ErrorAction Stop) }
                catch { throw 'FluxDown 管理接口响应格式无效' }
                finally { $reader.Dispose() }
            } finally { $response.Dispose() }
        } catch [Net.WebException] {
            $failure = $_.Exception
            if ($failure.Response) {
                $status = [int]$failure.Response.StatusCode
                try {
                    if ($status -eq 404 -and ($Route -eq 'info' -or ($Method -eq 'POST' -and $Route -eq 'tasks'))) {
                        $reader = New-Object IO.StreamReader($failure.Response.GetResponseStream(), [Text.Encoding]::UTF8)
                        try { $detail = $reader.ReadToEnd() | ConvertFrom-Json -ErrorAction Stop }
                        catch { $detail = $null }
                        finally { $reader.Dispose() }
                        if ((Get-EntryString $detail 'message') -ceq 'unknown endpoint') {
                            if ($Method -eq 'POST') { return @{ FallbackReason = '管理 API 未开启' } }
                            throw (New-Object Net.WebException '管理 API 未开启')
                        }
                    }
                } finally { $failure.Response.Dispose() }
                if ($status -in @(401,403)) {
                    $reason = 'Token 鉴权失败（HTTP {0}）' -f $status
                    if ($Method -eq 'POST' -and $Route -eq 'tasks') { return @{ FallbackReason = $reason } }
                    throw (New-Object Net.WebException $reason)
                }
                if ($status -eq 404 -and $Method -eq 'POST' -and $Route -eq 'tasks') {
                    return @{ FallbackReason = '管理接口未找到（HTTP 404）' }
                }
                if ($status -eq 404 -and $Method -eq 'GET' -and $Route -like 'tasks/*') { return }
                throw (New-Object Net.WebException ('FluxDown 管理接口返回 HTTP {0}' -f $status))
            }
            if (-not $Reconnect -or $attempt -ge 2) { throw (New-Object Net.WebException '无法连接 FluxDown 管理服务') }
            Start-Sleep -Milliseconds 500
        } finally { $request.Abort() }
    }
}
