#Requires -Version 5.1

function Get-ConfigValue {
    <#
    .SYNOPSIS
        从配置哈希表读取某个键的值，缺失时返回默认值。
    #>
    param(
        [hashtable]$Config,
        [Parameter(Mandatory = $true)]
        [string]$Key,
        $Default = $null
    )

    if ($Config -and $Config.ContainsKey($Key)) { return $Config[$Key] }
    return $Default
}
