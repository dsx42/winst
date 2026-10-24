#Requires -Version 5.1

function Get-WinstDevToolsValue {
    <#
    .SYNOPSIS
        在页面里执行一段 JS 并取回它的值（Runtime.evaluate，returnByValue）。
    #>
    param($Session, [string]$Expression, [switch]$AsPromise)

    $params = @{ expression = $Expression; returnByValue = $true }
    if ($AsPromise) { $params['awaitPromise'] = $true }
    $response = Invoke-WinstDevToolsCommand -Session $Session -Method 'Runtime.evaluate' -Params $params
    $value = $null
    try { $value = $response.result.result.value } catch { $value = $null }
    return $value
}
