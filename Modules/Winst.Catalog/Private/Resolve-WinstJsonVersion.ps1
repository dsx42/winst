#Requires -Version 5.1

function Resolve-WinstJsonVersion {
    <#
    .SYNOPSIS
        ④ 版本：versionKey 优先，其次 versionBetween / versionKind 从下载地址识别，最后回退条目 version。
    .OUTPUTS
        [string]
    #>
    param($Source, $Entry, $Chosen, [string]$ApiUrl, [string]$VersionKind, $VersionBetween, [string]$DownloadUrl, $Result)

    $versionKey = (Get-EntryString -Entry $Source -Key 'versionKey').Trim()
    $version = ''
    if ($versionKey) {
        $found = Get-JsonNodeValue -Node $Chosen -Key $versionKey
        if (-not $found.Ok -or -not $found.Text) {
            $Result.Error = ('JSON 接口 {0} 的条目里没有版本字段「{1}」（可用字段: {2}）；可能是接口变更，需要更新软件源' -f `
                $ApiUrl, $versionKey, (Get-JsonFieldNameText -Node $Chosen))
            return ''
        }
        $version = Get-NormalizedVersionString -Value $found.Text
    } elseif (@($VersionBetween).Count -gt 0) {
        $between = Get-VersionBetween -Spec $VersionBetween -Text $DownloadUrl
        if ($between.Ok) {
            $version = Get-NormalizedVersionString -Value $between.Value
        } else {
            $Result.Notes += ('未能从下载地址里取出 {0} 之间的内容作为版本号' -f ($VersionBetween -join ' … '))
        }
    } elseif ($VersionKind) {
        $found = Get-VersionValue -Text $DownloadUrl -Kind $VersionKind
        if ($found) {
            $version = Get-NormalizedVersionString -Value $found
        } else {
            $Result.Notes += ('未能从下载地址里识别出版本号（versionKind {0}）' -f $VersionKind)
        }
    }
    if (-not $version) {
        $version = Get-NormalizedVersionString -Value (Get-EntryString -Entry $Entry -Key 'version')
    }
    return $version
}
