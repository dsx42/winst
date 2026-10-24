#Requires -Version 5.1

function New-WinstUpdateEntryResult {
    <#
    .SYNOPSIS
        单条更新的结果骨架（结果列表里的一行）。
    .OUTPUTS
        [ordered]@{ ... }
    #>
    param([string]$Id, [string]$Name, [string]$Installed)

    return [ordered]@{
        Id = $Id; Name = $Name; Installed = $Installed; Latest = ''; LatestSource = ''
        Action = ''; Message = ''; ResolutionError = $false
        PackageVersion = ''; RemoteFresh = ''
        CompanionCount = 0; CompanionNames = @()
    }
}
