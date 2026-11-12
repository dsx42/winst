#Requires -Version 5.1

function Find-WinstSystemSevenZip {
    <#
    .SYNOPSIS
        从系统安装记录查找同时包含命令行程序和动态库的 7-Zip，用于解压引导包。
    .OUTPUTS
        @{ Ok; Dir; Error }
    #>
    $result = @{ Ok = $false; Dir = ''; Error = '' }
    try {
        $status = @{}
        $entries = @(Get-WinstInstalledRegistryEntries -Force -Status $status)
        if (-not $status.Ok) { throw ('无法检查系统 7-Zip：' + $status.Error) }
        foreach ($entry in $entries) {
            if ((Get-EntryString -Entry $entry -Key 'DisplayName') -notmatch '^7-Zip(?:\s|$)') { continue }
            $dir = Get-WinstRegistryEntryInstallDir -Entry $entry
            if (-not $dir -or -not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
            Assert-WinstSafeWritePath -Path $dir -Directory
            $complete = $true
            foreach ($name in @('7z.exe', '7z.dll')) {
                $path = Join-WinstPath $dir $name
                Assert-WinstSafeWritePath -Path $path
                if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $complete = $false; break }
            }
            if ($complete) { $result.Dir = $dir; break }
        }
        $result.Ok = $true
    } catch {
        $result.Error = $_.Exception.Message
    }
    return $result
}
