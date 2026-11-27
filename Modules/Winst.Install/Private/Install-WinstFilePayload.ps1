#Requires -Version 5.1

function Install-WinstFilePayload {
    <#
    .SYNOPSIS
        ② file：把主包复制到安装目录（临时文件 + 原子替换，失败时目标文件保持原样）。
    .OUTPUTS
        @{ Ok; Error }
    #>
    param([string]$InstallDir, [string]$PrimaryPath)

    try { Assert-WinstSafeWritePath -Path $InstallDir -Directory }
    catch { return @{ Ok = $false; Error = $_.Exception.Message } }

    $fileName = Split-Path -Leaf $PrimaryPath
    if (-not $fileName) { return @{ Ok = $false; Error = '安装包文件名不可用，无法落位单文件条目' } }
    if (-not (Test-Path -LiteralPath $InstallDir -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $InstallDir -Force -ErrorAction SilentlyContinue
    }
    $fileTarget = Join-WinstPath $InstallDir $fileName
    $fileTemp = Join-WinstPath $InstallDir ('.winst-new-' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + [IO.Path]::GetExtension($fileName))
    try {
        Assert-WinstSafeWritePath -Path $fileTarget
        Assert-WinstSafeWritePath -Path $fileTemp
        Copy-Item -LiteralPath $PrimaryPath -Destination $fileTemp -Force -ErrorAction Stop
        if (Test-Path -LiteralPath $fileTarget -PathType Leaf) {
            [IO.File]::Replace($fileTemp, $fileTarget, [System.Management.Automation.Language.NullString]::Value)
        } else {
            Move-Item -LiteralPath $fileTemp -Destination $fileTarget -Force -ErrorAction Stop
        }
    } catch {
        Remove-Item -LiteralPath $fileTemp -Force -ErrorAction SilentlyContinue
        return @{ Ok = $false; Error = ('复制程序文件失败：{0}' -f $_.Exception.Message) }
    }
    return @{ Ok = $true; Error = '' }
}
