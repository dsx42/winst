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

    $content = $Response.Content
    if ($content -is [byte[]]) {
        if ($content.Length -ge 2 -and $content[0] -eq 0xFF -and $content[1] -eq 0xFE) {
            return [Text.Encoding]::Unicode.GetString($content, 2, $content.Length - 2)
        }
        if ($content.Length -ge 2 -and $content[0] -eq 0xFE -and $content[1] -eq 0xFF) {
            return [Text.Encoding]::BigEndianUnicode.GetString($content, 2, $content.Length - 2)
        }
        if ($content.Length -ge 3 -and $content[0] -eq 0xEF -and $content[1] -eq 0xBB -and $content[2] -eq 0xBF) {
            return [Text.Encoding]::UTF8.GetString($content, 3, $content.Length - 3)
        }
        $charset = 'utf-8'
        try {
            $contentType = [string]$Response.Headers['Content-Type']
            if ($contentType -match 'charset=([^;]+)') { $charset = $Matches[1].Trim().Trim('"') }
        } catch {
            # 忽略头解析失败
        }
        try {
            $encoding = [Text.Encoding]::GetEncoding($charset)
        } catch {
            $encoding = [Text.Encoding]::UTF8
        }
        return $encoding.GetString($content)
    }
    return [string]$content
}
