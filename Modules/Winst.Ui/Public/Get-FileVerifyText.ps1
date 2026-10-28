#Requires -Version 5.1

function Get-FileVerifyText {
    <#
    .SYNOPSIS
        把解析锁文件条目的完整性校验声明格式化为可读文本；未声明返回空串。
    .DESCRIPTION
        识别器关键字表的唯一定义处是 Get-WinstHashRule（Winst.Store）。展示层不直接依赖
        Store，而是由调用方传入 -HashRule（Get-WinstHashRule 的结果）；不传时只按
        hashFrom 原样显示。
    #>
    param($File, $HashRule = $null)

    $hash = Get-EntryString -Entry $File -Key 'hash'
    if ($hash) { return ('下载后校验: sha256 {0}' -f $hash) }

    $hashFile = Get-EntryString -Entry $File -Key 'hashFile'
    if ($hashFile) {
        $hashFrom = (Get-EntryString -Entry $File -Key 'hashFrom')
        if (-not $hashFrom) { $hashFrom = 'sha256sums' }
        if ($hashFrom -ieq 'digest') {
            return ('下载后校验: 按文件名从 {0} 取摘要（MD5 / SHA-1 / SHA-256 / SHA-512，按长度判定）' -f $hashFile)
        }
        $kindText = $hashFrom
        if ($HashRule -and $HashRule.Valid) { $kindText = [string]$HashRule.Display }
        if ($HashRule -and $HashRule.NeedsFileName) {
            return ('下载后校验: 按文件名从 {0} 取 {1}' -f $hashFile, $kindText)
        }
        return ('下载后校验: 从 {0} 取 {1} 摘要' -f $hashFile, $kindText)
    }
    return ''
}
