#Requires -Version 5.1

function Move-WinstArchiveSelection {
    <#
    .SYNOPSIS
        把已安全定位的解压条目交付到目标；目录取内容，文件取自身，Copy 用于从 Temp 复制落位。
    #>
    param([string]$Path, [string]$DestDir, [switch]$Copy)

    Assert-WinstSafeWritePath -Path $Path
    Assert-WinstSafeWritePath -Path $DestDir -Directory
    $item = Get-WinstFileSystemItem -Path $Path -ErrorAction Stop
    if (-not (Test-WinstFileSystemPath -Path $DestDir -PathType Container)) {
        $null = [IO.Directory]::CreateDirectory((ConvertTo-WinstExtendedPath -Path $DestDir))
    }
    if ($item.PSIsContainer) {
        Assert-WinstTreeWithoutReparsePoint -Path $Path
        foreach ($child in @(Get-WinstChildItem -Path $Path -ErrorAction Stop)) {
            Move-WinstItemInto -Source $child -DestDir $DestDir -Copy:$Copy
        }
    } else {
        Move-WinstItemInto -Source $item -DestDir $DestDir -Copy:$Copy
    }
    return @{ Ok = $true; Error = '' }
}
