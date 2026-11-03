#Requires -Version 5.1

function Move-WinstArchiveSelection {
    <#
    .SYNOPSIS
        把已安全定位的解压条目交付到目标；仅显式选择时展开内层压缩文件。
    #>
    param([hashtable]$Context, [string]$Path, [string]$DestDir,
        [switch]$ExpandInner, [switch]$AllowSfxPayload)

    Assert-WinstSafeWritePath -Path $Path
    Assert-WinstSafeWritePath -Path $DestDir -Directory
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
    if (-not (Test-Path -LiteralPath $DestDir -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $DestDir -Force -ErrorAction Stop
    }
    if ($item.PSIsContainer) {
        Assert-WinstTreeWithoutReparsePoint -Path $Path
        foreach ($child in @(Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop)) {
            Move-WinstItemInto -Source $child -DestDir $DestDir
        }
    } elseif ($ExpandInner -and (Test-WinstArchiveFileByExtension -Path $Path)) {
        return (Expand-WinstArchiveLayout -Context $Context -ArchivePath $Path -DestDir $DestDir `
            -StripTopDir $false -AllowSfxPayload:$AllowSfxPayload)
    } else {
        Move-WinstItemInto -Source $item -DestDir $DestDir
    }
    return @{ Ok = $true; Error = '' }
}
