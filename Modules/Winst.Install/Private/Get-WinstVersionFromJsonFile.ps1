#Requires -Version 5.1

function Get-WinstVersionFromJsonFile {
    <#
    .SYNOPSIS
        detect.method = jsonFile：从 JSON 文件的指定字段读版本。
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

    $jsonKey = Get-EntryString -Entry $Detect -Key 'jsonKey'
    if (-not $jsonKey) { return }
    $probe = Resolve-WinstDetectFirstFile -Context $Context -Detect $Detect -InstallDir $InstallDir
    if (-not $probe.Ok) { return }
    $file = $probe.File
    $Result.Found = $true
    $obj = $null
    try { $obj = (Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue) | ConvertFrom-Json } catch { $obj = $null }
    if ($null -eq $obj) { return }
    $found = Get-JsonNodeValue -Node $obj -Key $jsonKey
    if (-not $found.Ok) { return }
    Set-WinstDetectedVersionFromRaw -Result $Result -Raw ([string]$found.Text) -Kind $Kind -Between $Between `
        -Detail ('JSON 文件: {0}（字段 {1}）' -f $file.FullName, $jsonKey)
}
