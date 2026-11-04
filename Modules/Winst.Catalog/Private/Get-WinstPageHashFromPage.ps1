#Requires -Version 5.1

function Get-WinstPageHashFromPage {
    <#
    .SYNOPSIS
        files[0].hashFrom: "page" —— 从下载页提取摘要，并记一条说明。
    .OUTPUTS
        [string] 摘要（未声明 / 无需提取时为空串）
    #>
    param($Item, [string]$Html, [string]$Url, [string]$PageUrl, $Result, [string]$BrowserPageHash = '')

    # files[].hashFrom: "page" —— 优先按文件名在页面条目内就近提取（如 NTriver ISO 列表）；
    # 摘要随上游换包而变，写死进清单反而在下次更新后校验失败。
    # 就近刮取失败且软件源声明了 source.hashClick 时，点击流程会在同一无头会话按 hashClick
    # 点控件并从可见文案读出唯一摘要（见 WantPageHash / Get-WinstBrowserPageHash）。
    # 提取结果当 hash 用（下载后照常比对），指令本身不进解析结果。
    if ($null -eq $Item -or ((Get-EntryString -Entry $Item -Key 'hashFrom').Trim() -ine 'page')) { return '' }
    if ((Get-EntryString -Entry $Item -Key 'hash').Trim()) {
        $Result.Error = 'files[0] 里 hash 与 hashFrom: "page" 只能写一个：hash 是写死的校验值，hashFrom: "page" 是从页面按文件名就近提取'
        return ''
    }
    $pageHash = Get-WinstPageFileHash -Html $Html -Url $Url
    $fromBrowserClick = $false
    if (-not $pageHash) {
        $browserHash = ([string]$BrowserPageHash).Trim().ToLowerInvariant()
        if ($browserHash -match '^[0-9a-f]{32}$|^[0-9a-f]{40}$|^[0-9a-f]{64}$|^[0-9a-f]{128}$') {
            $pageHash = $browserHash
            $fromBrowserClick = $true
        }
    }
    if (-not $pageHash) {
        $Result.Error = ('无法在下载页 {0} 上提取校验值（hashFrom: "page"）；可能是页面结构变更，需要更新软件源，或改在清单里写死 hash' -f $PageUrl)
        return ''
    }
    $hashAlgorithm = Get-HashAlgorithmFromDigestLength -Length $pageHash.Length
    if (-not $hashAlgorithm) { $hashAlgorithm = 'SHA-256' }
    if ($fromBrowserClick) {
        $Result.Notes += ('已从下载页点击后的文案提取主包的 {0}（{1}…）' -f $hashAlgorithm, $pageHash.Substring(0, [Math]::Min(8, $pageHash.Length)))
    } else {
        $Result.Notes += ('已按文件名从下载页提取主包的 {0}（{1}…）' -f $hashAlgorithm, $pageHash.Substring(0, [Math]::Min(8, $pageHash.Length)))
    }
    return $pageHash
}
