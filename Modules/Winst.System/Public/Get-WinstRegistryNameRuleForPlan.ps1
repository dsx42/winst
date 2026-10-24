#Requires -Version 5.1

function Get-WinstRegistryNameRuleForPlan {
    <#
    .SYNOPSIS
        取条目在系统安装记录（注册表卸载项）里的名称规则：detect.name 优先；未声明时仅 registry
        检测的条目按条目名称推导（与修复安装记录一致）。返回空串 = 没有可用规则。
    #>
    param($Plan)

    $detect = Get-EntryValue -Entry $Plan -Key 'detect' -Default $null
    $nameRule = Get-EntryString -Entry $detect -Key 'name'
    if ($nameRule) { return $nameRule }
    # 名称规则未声明：只有「以注册表为准」（installer 的默认检测方式）时才按条目名称推导，
    # 避免对刻意不用注册表检测的条目误配到同名软件
    $method = (Get-EntryString -Entry $detect -Key 'method').Trim().ToLowerInvariant()
    if ($method -and $method -ne 'registry') { return '' }
    $display = Get-EntryString -Entry $Plan -Key 'name'
    if (-not $display) { $display = Get-EntryString -Entry $Plan -Key 'id' }
    if (-not $display) { return '' }
    return ('*' + (ConvertTo-WildcardLiteral -Text $display) + '*')
}
