#Requires -Version 5.1

function Get-WinstVersionFromMarkerFile {
    <#
    .SYNOPSIS
        detect.method = markerFile：从标记文件内容里识别版本。
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

    $probe = Resolve-WinstDetectFirstFile -Context $Context -Detect $Detect -InstallDir $InstallDir
    if (-not $probe.Ok) { return }
    $file = $probe.File
    $Result.Found = $true
    $text = ''
    try { $text = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue } catch { $text = '' }
    # 标记文件内容常常就是版本号本身 → 无条件兜底（-Fallback always）
    Set-WinstDetectedVersionFromRaw -Result $Result -Raw $text -Kind $Kind -Between $Between `
        -Detail ('标记文件: {0}' -f $file.FullName) -Fallback always
}
