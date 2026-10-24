#Requires -Version 5.1

function Get-WinstChecksumDeclarationFingerprint {
    <#
    .SYNOPSIS
        为远程校验文件声明生成稳定指纹，防止离线时把旧校验值套到另一地址 / 版本的包上。
    #>
    param(
        [string]$FileName,
        $FileDecl,
        [string]$FileUrl = '',
        [string]$SourceVersion = ''
    )

    $hashFile = (Get-EntryString -Entry $FileDecl -Key 'hashFile').Trim()
    if (-not $hashFile) { return '' }
    $hashFrom = (Get-EntryString -Entry $FileDecl -Key 'hashFrom').Trim()
    if (-not $hashFrom) { $hashFrom = 'sha256sums' }
    $payload = @(
        ([string]$FileName).ToLowerInvariant(),
        ([string]$FileUrl).Trim(),
        ([string]$SourceVersion).Trim(),
        $hashFile,
        $hashFrom.ToLowerInvariant()
    ) -join "`n"
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
        return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally {
        $sha.Dispose()
    }
}
