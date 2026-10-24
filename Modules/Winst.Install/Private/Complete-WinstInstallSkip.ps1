#Requires -Version 5.1

function Complete-WinstInstallSkip {
    <#
    .SYNOPSIS
        填充统一的安装跳过结果，并返回决策函数的立即返回对象。
    #>
    param($Result, [string]$Version, [Parameter(Mandatory = $true)][string]$Message)

    $Result.Ok = $true
    $Result.Skipped = $true
    $Result.Version = $Version
    $Result.Message = $Message
    return @{ Return = $true; Result = $Result; Defer = $false; CompanionOnly = $false; Detected = $Version }
}
