#Requires -Version 5.1

function Get-WinstVersionFromMarkerFile {
    <#
    .SYNOPSIS
        detect.method = markerFile：从标记文件内容里识别版本。
    .DESCRIPTION
        pathGlob 可能命中多个标记文件（新旧两个版本目录并存时）：逐个识别，全部交给
        Complete-WinstDetectedVersion 挑出最新版本，其余作为「旧版本」返回。
    #>
    param(
        [hashtable]$Context,
        $Plan,
        $Detect,
        [string]$InstallDir = '',
        [string]$Kind = '',
        $Between = @(),
        [hashtable]$Result
    )

    $probe = Resolve-WinstDetectFiles -Context $Context -Detect $Detect -InstallDir $InstallDir
    if (-not $probe.Ok) { return }
    $Result.Found = $true

    foreach ($file in @($probe.Files)) {
        $text = ''
        try { $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue } catch { $text = '' }
        # 标记文件内容常常就是版本号本身 → 无条件兜底（-Fallback always）
        $one = @{ Ok = $false; Found = $true; Version = ''; Detail = '' }
        Set-WinstDetectedVersionFromRaw -Result $one -Raw $text -Kind $Kind -Between $Between `
            -Detail ('标记文件: {0}' -f $file.FullName) -Fallback always
        if (-not $one.Ok -or -not $one.Version) { continue }
        Add-WinstVersionItem -Result $Result -Version ([string]$one.Version) -Detail ([string]$one.Detail) `
            -GroupKey (Get-WinstPathGroupKey -Path $file.FullName)
    }
}
