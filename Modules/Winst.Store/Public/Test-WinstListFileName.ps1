#Requires -Version 5.1

function Test-WinstListFileName {
    <#
    .SYNOPSIS
        校验清单文件名：非空、无路径分隔符与非法字符、不以点开头，并补上 .list 后缀。
    .OUTPUTS
        @{ Ok; Error; Name }
    #>
    param([string]$Text)

    $name = ''
    if ($null -ne $Text) { $name = ([string]$Text).Trim().Trim('"') }
    if (-not $name) { return @{ Ok = $false; Error = '文件名为空。'; Name = '' } }
    if ($name -match '[\\/:*?"<>|]') {
        return @{ Ok = $false; Error = '文件名不能包含这些字符: \ / : * ? " < > |'; Name = '' }
    }
    if ($name -match '[\x00-\x1F]') {
        return @{ Ok = $false; Error = '文件名不能包含控制字符。'; Name = '' }
    }
    if ($name.StartsWith('.')) { return @{ Ok = $false; Error = '文件名不能以点开头。'; Name = '' } }
    if ($name.EndsWith('.')) { return @{ Ok = $false; Error = '文件名不能以点结尾。'; Name = '' } }
    if ($name -notmatch '(?i)\.list$') { $name = $name + '.list' }
    # 补后缀之后要再校验一次：`CON` 补成 `CON.list` 仍然落在设备上，`abc ` 补成 `abc .list` 带尾空格
    if (-not (Test-WinstSafePathSegment -Name $name -MaxLength 200)) {
        return @{ Ok = $false; Error = '文件名不合法（不能以点或空格结尾，不能是 CON / NUL / COM1 等保留设备名，长度不超过 200）。'; Name = '' }
    }
    return @{ Ok = $true; Error = ''; Name = $name }
}
