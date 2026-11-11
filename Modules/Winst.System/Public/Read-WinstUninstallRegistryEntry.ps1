#Requires -Version 5.1

function Read-WinstUninstallRegistryEntry {
    <#
    .SYNOPSIS
        实时读取指定视图的卸载记录，供卸载与旧版本检测使用；只有键不存在时返回空。
    #>
    param([string]$KeyPath)

    $key = Open-WinstUninstallRegistryKey -KeyPath $KeyPath
    if ($null -eq $key) { return $null }
    try {
        $row = [ordered]@{ KeyPath = $KeyPath }
        foreach ($field in @('DisplayName','DisplayVersion','InstallLocation','UninstallString','DisplayIcon')) {
            $row[$field] = [string]$key.GetValue($field, '')
        }
        return $row
    } finally { $key.Dispose() }
}
