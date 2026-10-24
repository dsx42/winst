#Requires -Version 5.1

function Format-BoolDisplay {
    param($Value)

    $parsed = Convert-WinstBoolText -Value $Value
    if ($null -eq $parsed) { return '未设置' }
    if ($parsed) { return '开' }
    return '关'
}
