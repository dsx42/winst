#Requires -Version 5.1

function Get-ConfigTag {
    <#
    .SYNOPSIS
        返回配置项按实际来源的标记：内置默认 → [默认]，用户改过 → [自定义]。
    .DESCRIPTION
        路径类配置还有优先级更高的临时来源，按实际生效者标注：
        [参数]（命令行）/ [环境变量] / [U盘]（脚本同目录 apps\）。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context,
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    switch ($Context[$Key + 'Source']) {
        'param'  { return '[参数]' }
        'env'    { return '[环境变量]' }
        'script' { return '[U盘]' }
    }

    $defaults = Get-WinstConfigDefaults -DataRoot $Context.DataRoot
    $defaultValue = Get-ConfigValue -Config $defaults -Key $Key
    $currentValue = Get-ConfigValue -Config $Context.Config -Key $Key

    if (Test-ConfigValueIsDefault -Value $currentValue -Default $defaultValue) { return '[默认]' }
    return '[自定义]'
}
