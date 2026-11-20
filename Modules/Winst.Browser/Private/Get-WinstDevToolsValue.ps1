#Requires -Version 5.1

function Get-WinstDevToolsValue {
    <#
    .SYNOPSIS
        在页面里执行一段 JS 并取回它的值（Runtime.evaluate，returnByValue）。
    #>
    param($Session, [string]$Expression)

    $params = @{ expression = $Expression; returnByValue = $true }
    $response = Invoke-WinstDevToolsCommand -Session $Session -Method 'Runtime.evaluate' -Params $params
    try { $value = $response.result.result.value } catch { $value = $null }
    return $value
}
