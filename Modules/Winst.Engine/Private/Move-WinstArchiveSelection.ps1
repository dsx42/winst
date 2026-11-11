#Requires -Version 5.1

function Move-WinstArchiveSelection {
    <#
    .SYNOPSIS
        把已安全定位的解压条目交付到目标；目录取内容，文件取自身。
    #>
    param([string]$Path, [string]$DestDir)

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
    } else {
        Move-WinstItemInto -Source $item -DestDir $DestDir
    }
    return @{ Ok = $true; Error = '' }
}
