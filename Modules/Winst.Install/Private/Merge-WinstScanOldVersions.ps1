#Requires -Version 5.1

function Merge-WinstScanOldVersions {
    <#
    .SYNOPSIS
        把本次扫描到的「同一软件并存的低版本」整理成可直接写进台账的登记。
    .DESCRIPTION
        只保留版本号低于当前版本的条目（同一版本不该被记成旧版本），按版本号去重。
        本次一个都没扫到就返回空数组：旧版本已经不在本机了，留着只会让界面一直提醒。
    .OUTPUTS
        [object[]]：`[ordered]@{ version; detail; recordKey }`
    #>
    param($Info, [string]$CurrentVersion)

    $result = @()
    $seen = New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($item in @(Get-EntryArray -Entry $Info -Key 'OldVersions')) {
        $version = Get-EntryString -Entry $item -Key 'version'
        if (-not $version) { continue }
        if ($CurrentVersion -and $CurrentVersion -ne 'unknown') {
            $cmp = 0
            try { $cmp = Compare-WinstVersion -A $version -B $CurrentVersion } catch { $cmp = 0 }
            if ($cmp -ge 0) { continue }
        }
        if ($seen.ContainsKey($version)) { continue }
        $seen[$version] = $true
        $result += [ordered]@{
            version   = $version
            detail    = (Get-EntryString -Entry $item -Key 'detail')
            recordKey = (Get-EntryString -Entry $item -Key 'recordKey')
        }
    }
    return $result
}
