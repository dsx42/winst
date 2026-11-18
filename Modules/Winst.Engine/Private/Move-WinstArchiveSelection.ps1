#Requires -Version 5.1

function Move-WinstArchiveSelection {
    <#
    .SYNOPSIS
        把已安全定位的解压条目交付到目标；目录取内容，文件取自身，Copy 用于从 Temp 复制落位。
    #>
    param([string]$Path, [string]$DestDir, [switch]$Copy, [switch]$Clean, [string[]]$Keep = @())

    Assert-WinstSafeWritePath -Path $Path
    Assert-WinstSafeWritePath -Path $DestDir -Directory
    $item = Get-WinstFileSystemItem -Path $Path -ErrorAction Stop
    $destination = Get-WinstFileSystemItem -Path $DestDir -AllowMissing
    if ($null -ne $destination -and -not $destination.PSIsContainer) { throw ('安装目标不是目录：' + $DestDir) }
    if ($Clean) { Clear-WinstInstallDir -Dir $DestDir -Keep $Keep -Strict }
    if (-not (Test-WinstFileSystemPath -Path $DestDir -PathType Container)) {
        $null = [IO.Directory]::CreateDirectory((ConvertTo-WinstExtendedPath -Path $DestDir))
    }
    $destIo = ConvertTo-WinstExtendedPath -Path $DestDir
    if ($item.PSIsContainer) {
        Get-WinstChildItem -Path $Path -ErrorAction Stop | ForEach-Object {
            Move-WinstItemInto -Source $_ -DestDir $DestDir -Copy:$Copy -DestIo $destIo
        }
    } else {
        Move-WinstItemInto -Source (Get-WinstFileSystemItem -Path $Path) -DestDir $DestDir -Copy:$Copy -DestIo $destIo
    }
    return @{ Ok = $true; Error = '' }
}
