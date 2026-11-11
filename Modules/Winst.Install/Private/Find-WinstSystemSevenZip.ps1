#Requires -Version 5.1

function Find-WinstSystemSevenZip {
    <#
    .SYNOPSIS
        从系统安装记录查找与目标版本一致、同时包含命令行程序和动态库的 7-Zip。
    .OUTPUTS
        @{ Ok; Dir; InstallDir; Error }；Dir 是匹配版本目录，InstallDir 是已有系统安装目录。
    #>
    param([string]$Version)

    $result = @{ Ok = $false; Dir = ''; InstallDir = ''; Error = '' }
    try {
        $status = @{}
        $entries = @(Get-WinstInstalledRegistryEntries -Force -Status $status)
        if (-not $status.Ok) { throw ('无法检查系统 7-Zip：' + $status.Error) }
        foreach ($entry in $entries) {
            if ((Get-EntryString -Entry $entry -Key 'DisplayName') -notmatch '^7-Zip(?:\s|$)') { continue }
            $dir = Get-WinstRegistryEntryInstallDir -Entry $entry
            if (-not $dir -or -not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
            Assert-WinstSafeWritePath -Path $dir -Directory
            if (-not $result.InstallDir) { $result.InstallDir = $dir }
            $matchesVersion = $true
            foreach ($name in @('7z.exe', '7z.dll')) {
                $path = Join-WinstPath $dir $name
                Assert-WinstSafeWritePath -Path $path
                if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { $matchesVersion = $false; break }
                $actual = Get-WinstPackageDerivedVersion -Plan @{} -PkgDir $dir -FileName $name
                if (-not $actual.Ok) { throw ('无法读取系统 7-Zip 文件版本（{0}）：{1}' -f $path, $actual.Error) }
                if ((Compare-WinstVersion -A $actual.Version -B '0') -eq 0) { throw ('系统 7-Zip 文件没有有效版本资源：' + $path) }
                if ((Compare-WinstVersion -A $actual.Version -B $Version) -ne 0) {
                    $matchesVersion = $false
                    break
                }
            }
            if ($matchesVersion) { $result.Dir = $dir; break }
        }
        $result.Ok = $true
    } catch {
        $result.Error = $_.Exception.Message
    }
    return $result
}
