#Requires -Version 5.1

function Read-WinstJsonSourceResponse {
    <#
    .SYNOPSIS
        使用现有 HTTP 缓存与代理读取 JSON 来源响应。
    #>
    param([hashtable]$Context, [string]$ApiUrl)

    try {
        $text = Invoke-WinstHttpGet -Uri $ApiUrl -Context $Context -Headers (Get-WinstBrowserHeaders)
    } catch {
        return @{ Error = ('无法打开 JSON 接口 {0}：{1}' -f $ApiUrl, $_.Exception.Message); Data = $null }
    }
    $data = $null
    try { $data = $text | ConvertFrom-Json -ErrorAction Stop } catch { }
    if ($null -eq $data) {
        return @{ Error = ('JSON 接口 {0} 返回的内容不是合法 JSON；可能是接口变更，需要更新软件源' -f $ApiUrl); Data = $null }
    }
    return @{ Error = ''; Data = $data }
}
