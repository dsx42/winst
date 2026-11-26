#Requires -Version 5.1

function Get-WinstFluxTaskPath {
    param([string]$DestDir)

    $id = Split-Path -Leaf (Split-Path -Parent $DestDir)
    if (-not (Test-WinstSafePathSegment -Name $id)) { throw '下载目录所属的软件 ID 无效' }
    $path = Join-Path (Join-Path $DestDir '.tasks') ($id + '.json')
    Assert-WinstSafeWritePath -Path $path
    return $path
}
