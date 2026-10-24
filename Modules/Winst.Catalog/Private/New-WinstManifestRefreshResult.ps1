#Requires -Version 5.1

function New-WinstManifestRefreshResult {
    <#
    .SYNOPSIS
        刷新结果骨架（字段与 Update-ManifestSource 的 .OUTPUTS 一致）。
    .OUTPUTS
        [hashtable]
    #>
    param([string]$Name, [switch]$IsLocal)

    return @{
        Name            = $Name
        Success         = $false
        Version         = ''
        Message         = ''
        Network         = $false
        Apps            = @()
        Resolved        = 0
        ResolveFailed   = 0
        Retained        = 0
        RetainedReasons = @()
        Total           = 0
        LocalManifest   = [bool]$IsLocal
        Files           = @()
    }
}
