#Requires -Version 5.1

function Read-WinstRegistryEntryFields {
    param($Key, [string]$KeyPath)

    $row = [ordered]@{ KeyPath = $KeyPath }
    foreach ($field in @('DisplayName','DisplayVersion','InstallLocation','UninstallString','DisplayIcon')) {
        $row[$field] = [string]$Key.GetValue($field, '')
    }
    return $row
}
