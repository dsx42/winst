#Requires -Version 5.1

function Get-WinstEnvironmentPathSnapshot {
    param([string]$Name, [hashtable]$Changes)

    if ($null -ne $Changes -and $Changes['LiteralPath'] -and $Name -ine 'Path') { return $null }
    $segments = @()
    $literal = $true
    foreach ($scope in @('Machine','User')) {
        $raw = [string](Get-WinstEnvironmentValue -Name 'Path' -Scope $scope)
        if ($raw.Contains('%')) { $literal = $false }
        $segments += @(Get-WinstPathSegments -Value ([Environment]::ExpandEnvironmentVariables($raw)))
    }
    if ($null -ne $Changes) { $Changes['LiteralPath'] = $literal -and $Name -ine 'Path' }
    return @{ Persistent = $segments; Session = [Environment]::GetEnvironmentVariable('Path', 'Process') }
}
