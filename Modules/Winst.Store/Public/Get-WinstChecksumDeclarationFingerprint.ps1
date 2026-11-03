#Requires -Version 5.1

function Get-WinstChecksumDeclarationFingerprint {
    <#
    .SYNOPSIS
        为远程校验声明生成稳定指纹，防止把旧校验值套到另一地址 / 版本的包上。
    .DESCRIPTION
        版本维度是**这个文件自己的版本**（主包版本；附加文件只有声明 versionListUrl 并独立取版时才有，
        跟随主包版本的附加文件为空）。这样主包升版不会无谓地让附件重取校验文件，
        而附件自己的版本变化仍会让旧摘要失效。
    #>
    param(
        [string]$FileName,
        $FileDecl,
        [string]$FileUrl = '',
        [string]$FileVersion = ''
    )

    $hashFile = (Get-EntryString -Entry $FileDecl -Key 'hashFile').Trim()
    if (-not $hashFile) { return '' }
    $hashFrom = (Get-EntryString -Entry $FileDecl -Key 'hashFrom').Trim()
    if (-not $hashFrom) { $hashFrom = 'sha256sums' }
    $payload = @(
        ([string]$FileName).ToLowerInvariant(),
        ([string]$FileUrl).Trim(),
        ([string]$FileVersion).Trim(),
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
