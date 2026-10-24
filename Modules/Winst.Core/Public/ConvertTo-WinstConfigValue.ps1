#Requires -Version 5.1

function ConvertTo-WinstConfigValue {
    <#
    .SYNOPSIS
        按配置项当前值的类型，把用户在设置界面输入的文本转换成应有的类型（布尔 / 数字 / 文本）。
    .OUTPUTS
        @{ Ok; Value; Error }
    #>
    param($Current, [string]$Text)

    $result = @{ Ok = $false; Value = $null; Error = '' }
    $value = ''
    if ($null -ne $Text) { $value = ([string]$Text).Trim() }
    if (-not $value) {
        $result.Error = '不能为空'
        return $result
    }

    if ($Current -is [bool]) {
        $parsedBool = Convert-WinstBoolText -Value $value
        if ($null -ne $parsedBool) { $result.Value = $parsedBool; $result.Ok = $true; return $result }
        $result.Error = '请输入「开」或「关」'
        return $result
    }
    if ($Current -is [int] -or $Current -is [long]) {
        $number = 0
        if (-not [int]::TryParse($value, [ref]$number)) {
            $result.Error = '请输入数字'
            return $result
        }
        $result.Value = $number
        $result.Ok = $true
        return $result
    }

    $result.Value = $value
    $result.Ok = $true
    return $result
}
