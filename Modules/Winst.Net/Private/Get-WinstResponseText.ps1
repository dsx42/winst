#Requires -Version 5.1

function Get-WinstResponseText {
    <#
    .SYNOPSIS
        把 Invoke-WebRequest 响应转换为文本（字节响应按 charset 解码，缺省 UTF-8）。
    .DESCRIPTION
        字节流自带 BOM 时按 BOM 解码（优先于响应头声明的 charset，并去掉 BOM 本身）：
        个别官方校验文件是 Windows 记事本系工具生成的 UTF-16（如 PowerShell 发布的 hashes.sha256），
        响应头却标着 octet-stream / utf-8——不认 BOM 就会把正文解成夹着 NUL 的乱码，逐行解析全部失效。
    #>
    param($Response)

    $charset = 'utf-8'
    $headers = Get-EntryValue -Entry $Response -Key 'Headers'
    if ($headers -and ([string]$headers['Content-Type']) -match 'charset=([^;]+)') {
        $charset = $Matches[1].Trim().Trim('"')
    }
    try { $encoding = [Text.Encoding]::GetEncoding($charset) }
    catch { $encoding = [Text.Encoding]::UTF8 }

    $stream = Get-EntryValue -Entry $Response -Key 'RawContentStream' -Default $null
    $owned = $false
    if ($stream -isnot [IO.Stream] -or -not $stream.CanRead -or -not $stream.CanSeek) {
        $content = $Response.Content
        if ($content -isnot [byte[]]) { return [string]$content }
        $stream = [IO.MemoryStream]::new($content, $false)
        $owned = $true
    }
    $position = $stream.Position
    $reader = $null
    try {
        $stream.Position = 0
        $reader = [IO.StreamReader]::new($stream, $encoding, $true, 4096, $true)
        return $reader.ReadToEnd()
    } finally {
        if ($reader) { $reader.Dispose() }
        if ($owned) { $stream.Dispose() } else { $stream.Position = $position }
    }
}
