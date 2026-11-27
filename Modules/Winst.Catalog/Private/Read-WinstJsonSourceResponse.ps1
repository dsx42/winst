#Requires -Version 5.1

function Read-WinstJsonSourceResponse {
    param([hashtable]$Context, [string]$ApiUrl, [hashtable]$Headers)

    try {
        $text = Invoke-WinstHttpGet -Uri $ApiUrl -Context $Context -Headers $Headers
        $data = ConvertFrom-Json -InputObject $text -ErrorAction Stop
        if ($null -eq $data) { throw '接口未返回可用数据' }
        return ,$data
    } catch {
        throw ('读取 JSON 接口 {0} 失败：{1}' -f $ApiUrl, $_.Exception.Message)
    }
}
