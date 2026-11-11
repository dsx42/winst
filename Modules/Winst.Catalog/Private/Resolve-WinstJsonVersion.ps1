#Requires -Version 5.1

function Resolve-WinstJsonVersion {
    <#
    .SYNOPSIS
        ④ 版本：versionKey 优先，否则组合 versionBetween / versionKind；没有识别规则时采用条目 version。
    .OUTPUTS
        [string]
    #>
    param($Source, $Entry, $Chosen, [string]$ApiUrl, [string]$DownloadUrl, $Result)

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
    } else {
        $found = Get-VersionFromSourceText -Source $Source -Text $DownloadUrl -Where '下载地址'
        if ($found.Missing) {
            $version = Get-NormalizedVersionString -Value (Get-EntryString -Entry $Entry -Key 'version')
        } elseif (-not $found.Ok) {
            $Result.Error = [string]$found.Error
            return ''
        } else {
            $version = [string]$found.Version
        }
    }
    return $version
}
