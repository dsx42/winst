#Requires -Version 5.1

function Get-WinstBrowserFileHeaders {
    <#
    .SYNOPSIS
        读取实际文件请求的请求头；尚未请求的链接按目标地址取 Cookie 和页面的引用策略。
    #>
    param($Session, [string]$Url)

    $headers = @{}
    $request = $Session.RequestHeaders[$Url]
    if ($request) {
        $extras = $Session.ExtraHeaders[$request.Id]
        if ($null -ne $extras -and $request.Hop -lt $extras.Count) {
            foreach ($name in @('Cookie', 'Referer', 'User-Agent')) {
                $value = Get-EntryString $extras[$request.Hop] $name
                if ($value) { $headers[$name] = $value }
            }
            return $headers
        }
    }
    $quotedUrl = ConvertTo-Json -InputObject $Url -Compress
    $page = Get-WinstDevToolsValue -Session $Session -Expression @"
(() => {
  const link = Array.from(document.links).find(a => a.href === $quotedUrl);
  const meta = Array.from(document.querySelectorAll('meta[name=referrer i]')).pop();
  return {url: location.href, ua: navigator.userAgent,
    policy: (link && link.relList.contains('noreferrer')) ? 'no-referrer' :
      ((link && link.referrerPolicy) || (meta && meta.content) || '')};
})()
"@
    $headers['User-Agent'] = [string]$page.ua
    $target = [uri]$Url
    $origin = New-Object UriBuilder ([uri]$page.url)
    $origin.Fragment = ''
    $origin.UserName = ''
    $origin.Password = ''
    $originUrl = $origin.Uri
    $sameOrigin = $originUrl.GetLeftPart('Authority') -ieq $target.GetLeftPart('Authority')
    if ($request) {
        $referer = Get-EntryString $request.Headers 'Referer'
    } else {
        $policy = [string]$page.policy
        if (-not $policy) { $policy = [string]$Session.ReferrerPolicies[$originUrl.AbsoluteUri] }
        $policy = ($policy.Split(',')[-1]).Trim().ToLowerInvariant()
        $downgrade = $originUrl.Scheme -eq 'https' -and $target.Scheme -eq 'http'
        $referer = ''
        if ($policy -eq 'unsafe-url' -or ($policy -eq 'no-referrer-when-downgrade' -and -not $downgrade) -or
                ($sameOrigin -and @('no-referrer', 'origin', 'strict-origin') -notcontains $policy)) {
            $referer = $originUrl.AbsoluteUri
        } elseif ($policy -eq 'origin' -or $policy -eq 'origin-when-cross-origin' -or
                (-not $downgrade -and @('no-referrer', 'same-origin') -notcontains $policy)) {
            $referer = $originUrl.GetLeftPart('Authority') + '/'
        }
    }
    if ($referer) { $headers['Referer'] = $referer }

    $response = Invoke-WinstDevToolsCommand -Session $Session -Method 'Network.getCookies' -Params @{ urls = @($Url) }
    $sameSite = $originUrl.Scheme -eq $target.Scheme -and $originUrl.Host -eq $target.Host
    $strictCookies = @($response.result.cookies | Where-Object { (Get-EntryString $_ 'sameSite') -eq 'Strict' })
    if (-not $sameSite -and $strictCookies.Count -and $originUrl.Scheme -eq $target.Scheme) {
        $sourceSite = Invoke-WinstDevToolsCommand -Session $Session -Method 'Network.fetchSchemefulSite' -Params @{ origin = $originUrl.GetLeftPart('Authority') }
        $targetSite = Invoke-WinstDevToolsCommand -Session $Session -Method 'Network.fetchSchemefulSite' -Params @{ origin = $target.GetLeftPart('Authority') }
        $sameSite = $sourceSite.result.schemefulSite -eq $targetSite.result.schemefulSite
    }
    $cookies = foreach ($cookie in @($response.result.cookies | Sort-Object { $_.path.Length } -Descending)) {
        if (-not $sameSite -and (Get-EntryString $cookie 'sameSite') -eq 'Strict') { continue }
        '{0}={1}' -f $cookie.name, $cookie.value
    }
    if ($cookies) { $headers['Cookie'] = $cookies -join '; ' }
    return $headers
}