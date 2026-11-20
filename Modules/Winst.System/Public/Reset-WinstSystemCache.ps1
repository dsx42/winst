#Requires -Version 5.1

function Reset-WinstSystemCache {
    <#
    .SYNOPSIS
        清空注册表卸载项、环境变量、Appx 包和引擎路径的缓存。
    #>
    $null = Set-WinstState -Name WinstRegistryEntriesCache -Value ($null)
    $null = Set-WinstState -Name WinstEnvironmentCache -Value ($null)
    $null = Set-WinstState -Name WinstAppxCache -Value ($null)
    $null = Set-WinstState -Name WinstEnginePathCache -Value ($null)
}
