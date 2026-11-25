#Requires -Version 5.1

function Get-WinstFluxTaskPath {
    param([string]$DestDir, [string]$FileName)

    if ($FileName -eq '.tasks' -or -not (Test-WinstSafePathSegment -Name $FileName)) { throw '暂存文件名无效' }
    $path = Join-Path (Join-Path $DestDir '.tasks') $FileName
    Assert-WinstSafeWritePath -Path $path
    return $path
}
