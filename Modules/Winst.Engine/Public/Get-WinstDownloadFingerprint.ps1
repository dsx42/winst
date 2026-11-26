#Requires -Version 5.1

function Get-WinstDownloadFingerprint {
    # 仅保存不可逆的请求指纹，避免将签名地址或凭据写入共享缓存。
    param([string]$Text)

    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($Text))).Replace('-', '')
    } finally { $sha.Dispose() }
}
