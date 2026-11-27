#Requires -Version 5.1

function Read-WinstYamlSourceResponse {
    param([hashtable]$Context, [string]$ApiUrl, [hashtable]$Headers)

    try {
        $text = Invoke-WinstHttpGet -Uri $ApiUrl -Context $Context -Headers $Headers
        return ,(ConvertFrom-WinstYaml -Text $text)
    } catch {
        throw ('读取 YAML 接口 {0} 失败：{1}' -f $ApiUrl, $_.Exception.Message)
    }
}
