#Requires -Version 5.1

function Get-WinstPageHashFromPage {
    <#
    .SYNOPSIS
        files[0].hashFrom: "page" —— 按文件名在页面上就近提取摘要，并记一条说明。
    .OUTPUTS
        [string] 摘要（未声明 / 无需提取时为空串）
    #>
    param($Item, [string]$Html, [string]$Url, [string]$PageUrl, $Result)

    # files[].hashFrom: "page" —— 页面按「文件名 + 摘要」排列时按文件名就近提取校验值（如 NTriver 的
    # ISO 列表、飞牛官网的 MD5），摘要随上游换包而变，写死进清单反而在下次更新后校验失败；提取结果
    # 当 hash 用（下载后照常比对），指令本身不进解析结果。click 与 link 两条取址路共用：
    # click 源声明了它时，点击流程会把点击后的 DOM 一并带回来（见 wantPageHash），从这里提取
    if ($null -eq $Item -or ((Get-EntryString -Entry $Item -Key 'hashFrom').Trim() -ine 'page')) { return '' }
    if ((Get-EntryString -Entry $Item -Key 'hash').Trim()) {
        $Result.Error = 'files[0] 里 hash 与 hashFrom: "page" 只能写一个：hash 是写死的校验值，hashFrom: "page" 是从页面按文件名就近提取'
        return ''
    }
    $pageHash = Get-WinstPageFileHash -Html $Html -Url $Url
    if (-not $pageHash) {
        $Result.Error = ('无法在下载页 {0} 上按文件名就近提取校验值（hashFrom: "page"）；可能是页面结构变更，需要更新软件源，或改在清单里写死 hash' -f $PageUrl)
        return ''
    }
    $hashAlgorithm = Get-HashAlgorithmFromDigestLength -Length $pageHash.Length
    if (-not $hashAlgorithm) { $hashAlgorithm = 'SHA-256' }
    $Result.Notes += ('已按文件名从下载页提取主包的 {0}（{1}…）' -f $hashAlgorithm, $pageHash.Substring(0, [Math]::Min(8, $pageHash.Length)))
    return $pageHash
}
