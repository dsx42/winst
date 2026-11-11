#Requires -Version 5.1

function Copy-WinstManifestFields {
    <#
    .SYNOPSIS
        复制清单对象并校验字段名、字符串与布尔类型，不修改调用方对象。
    #>
    param($Value, [string]$Label, [string[]]$Fields, [string[]]$Strings = @(), [string[]]$Booleans = @())

    if ($Value -isnot [System.Collections.IDictionary] -and $Value -isnot [pscustomobject]) {
        throw ($Label + ' 必须是对象')
    }
    $copy = Copy-WinstObjectShallow -InputObject $Value
    foreach ($key in @($copy.Keys)) {
        if ($Fields -notcontains $key) { throw ($Label + ' 不支持字段：' + $key) }
        if ($Strings -contains $key -and $copy[$key] -isnot [string]) {
            throw ($Label + '.' + $key + ' 必须是字符串')
        }
        if ($Booleans -contains $key -and $copy[$key] -isnot [bool]) {
            $text = ([string]$copy[$key]).Trim()
            if (@('true', 'false', '1', '0', 'yes', 'no', 'on', 'off') -notcontains $text) {
                throw ($Label + '.' + $key + ' 必须是布尔值')
            }
            $copy[$key] = @('true', '1', 'yes', 'on') -contains $text
        }
    }
    return $copy
}