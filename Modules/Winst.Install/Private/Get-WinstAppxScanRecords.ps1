#Requires -Version 5.1

function Get-WinstAppxScanRecords {
    <#
    .SYNOPSIS
        ③′ 扫描系统应用包记录（detect.method = appx 的条目），命中即写入 found。
    #>
    param([hashtable]$Context, $Plan, $Source, $Found, [switch]$Quiet, [switch]$VerboseOutput)

    # Windows App Runtime 这类软件：安装包是 .exe 安装器，装完以应用包（MSIX）存在——既没有
    # installRoot 下的安装目录，也不写注册表卸载项（上面 ①②③ 都扫不到），只能按清单 detect
    # 从系统的应用包记录里识别；命中即登记（managed = external，卸载方式按当前清单执行）。
    $appxIds = @()
    foreach ($id in @($Plan.Keys)) {
        if ($Found.Contains($id)) { continue }
        $detect = Get-EntryValue -Entry $Plan[$id] -Key 'detect' -Default $null
        if ((Get-EntryString -Entry $detect -Key 'method').Trim().ToLowerInvariant() -eq 'appx') { $appxIds += $id }
    }
    if ($appxIds.Count -eq 0) { return }

    if (-not $Quiet) { Write-Host '  正在扫描系统应用包记录 …' -ForegroundColor Gray }
    foreach ($id in $appxIds) {
        $app = $Plan[$id]
        $detectResult = Get-WinstDetectedVersion -Context $Context -Plan $app -InstallDir '' -SourceName ([string]$Source[$id])
        if (-not ($detectResult.Ok -and [string]$detectResult.Version)) {
            if ($VerboseOutput) {
                Write-Host ('    [应用包] {0} → 没有找到已安装的应用包' -f $id) -ForegroundColor DarkGray
            }
            continue
        }
        $location = [string]$detectResult['Location']
        $Found[$id] = New-WinstScanRecord -Id $id -Version ([string]$detectResult.Version) `
            -Type ((Get-EntryString -Entry $app -Key 'type').Trim().ToLowerInvariant()) `
            -InstallDir $location -Managed 'external' -Source ([string]$Source[$id])
        if ($VerboseOutput) {
            $detail = [string]$detectResult.Detail
            if ($detail) { $detail = ('，{0}' -f $detail) }
            Write-Host ('    [应用包] {0} → 版本 {1}{2}' -f $id, [string]$detectResult.Version, $detail) -ForegroundColor DarkGray
        }
    }
}
