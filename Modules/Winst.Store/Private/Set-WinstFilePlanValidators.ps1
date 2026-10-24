#Requires -Version 5.1

function Set-WinstFilePlanValidators {
    <#
    .SYNOPSIS
        HEAD 取一次校验器并写进计划（取到几项写几项，失败静默）。
    #>
    param($Plan, [hashtable]$Context, [string]$Uri, [switch]$RequireFields)

    $validators = Get-WinstRemoteValidators -Context $Context -Uri $Uri
    if (-not $validators.Ok) { return }
    # 首次下载建基线时要求至少取到一项；FreshMain 口径只要求 Ok（与拆分前一致）
    if ($RequireFields -and -not $validators.ETag -and -not $validators.LastModified -and $null -eq $validators.Size) { return }

    $Plan['ValidatorETag'] = [string]$validators.ETag
    $Plan['ValidatorLastModified'] = [string]$validators.LastModified
    if ($null -ne $validators.Size) { $Plan['ValidatorSize'] = $validators.Size }
    $Plan['CheckedAt'] = (Get-Date).ToString('s')
}
