#Requires -Version 5.1

function Get-WinstVersionFromJsonFile {
    <#
    .SYNOPSIS
        detect.method = jsonFile：从 JSON 文件的指定字段读版本。
    .DESCRIPTION
        pathGlob 可能命中多个 JSON 文件（同一软件的新旧两个版本目录并存时）：逐个读出 jsonKey 字段，
        全部交给 Complete-WinstDetectedVersion 挑出最新版本，其余作为「旧版本」返回。
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
    $probe = Resolve-WinstDetectFiles -Context $Context -Detect $Detect -InstallDir $InstallDir
    if (-not $probe.Ok) { return }
    $Result.Found = $true

    foreach ($file in @($probe.Files)) {
        $obj = $null
        try { $obj = (Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue) | ConvertFrom-Json } catch { $obj = $null }
        if ($null -eq $obj) { continue }
        $found = Get-JsonNodeValue -Node $obj -Key $jsonKey
        if (-not $found.Ok) { continue }
        $one = @{ Ok = $false; Found = $true; Version = ''; Detail = '' }
        Set-WinstDetectedVersionFromRaw -Result $one -Raw ([string]$found.Text) -Kind $Kind -Between $Between `
            -Detail ('JSON 文件: {0}（字段 {1}）' -f $file.FullName, $jsonKey)
        if (-not $one.Ok -or -not $one.Version) { continue }
        Add-WinstVersionItem -Result $Result -Version ([string]$one.Version) -Detail ([string]$one.Detail) `
            -GroupKey (Get-WinstPathGroupKey -Path $file.FullName)
    }
}
