#Requires -Version 5.1

function Complete-WinstEnvironmentChanges {
    param([hashtable]$Changes)
    if ($null -ne $Changes -and $Changes['Changed']) {
        Send-WinstSettingChange
        $Changes.Clear()
    }
}
