#Requires -Version 5.1

function Get-WinstVersionFromFileVersion {
    <#
    .SYNOPSIS
        detect.method = fileVersion：读命中文件的文件版本（字符串与数值体不一致时按既有口径取舍）。
    .DESCRIPTION
        pathGlob 可能命中多个文件（同一软件的新旧两个版本目录并存时就会这样）：逐个读出文件版本，
        全部交给 Complete-WinstDetectedVersion 挑出最新版本，其余作为「旧版本」返回。
    #>
    param(
        [hashtable]$Context,
        $Detect,
        [string]$InstallDir,
        [string]$Kind,
        $Between,
        [hashtable]$Result
    )

    $probe = Resolve-WinstDetectFiles -Context $Context -Detect $Detect -InstallDir $InstallDir
    if (-not $probe.Ok) { return }
    $Result.Found = $true

    foreach ($file in @($probe.Files)) {
        try { $raw = Get-WinstFileResourceVersion -VersionInfo $file.VersionInfo }
        catch { $raw = '' }
        $value = Get-WinstVersionFromText -Text $raw -Kind $Kind -Between $Between
        # 文件版本号本身就是版本：没声明识别器时按「第一个像版本号的内容」兜底
        if (-not $value -and -not $Kind -and -not (@($Between).Count -gt 0)) { $value = Get-WinstFirstVersionLike -Text $raw }
        if (-not $value) { continue }
        # 同一产品的判定用「抹掉版本目录的路径」：`.NET Runtime\10.0.13\coreclr.dll` 与
        # `10.0.14\coreclr.dll` 抹完相同（同一产品的新旧两版）；VC++ 2019 与 2022 装在不同目录、
        # 本身就是两个可以并存的产品，不会互相报成旧版本
        Add-WinstVersionItem -Result $Result -Version $value -Detail ('文件: {0}' -f $file.FullName) `
            -GroupKey (Get-WinstPathGroupKey -Path $file.FullName)
    }

    if ($probe.Files.Count -gt 1 -and (Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
        Write-Host ('  [verbose] 版本检测命中 {0} 个文件，取版本最高的那个' -f $probe.Files.Count) -ForegroundColor DarkGray
    }
}
