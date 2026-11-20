#Requires -Version 5.1

function Resolve-WinstJsonVersion {
    <#
    .SYNOPSIS
        优先读取 versionKey，否则从下载地址提取版本。未声明规则时返回空串。
    .OUTPUTS
        [string]
    #>
    param($Source, $Chosen, [string]$ApiUrl, [string]$DownloadUrl, $Result)

    $versionKey = (Get-EntryString -Entry $Source -Key 'versionKey').Trim()
    if ($versionKey) {
        $found = Get-JsonNodeValue -Node $Chosen -Key $versionKey
        if (-not $found.Ok -or -not $found.Text) {
            $Result.Error = ('JSON 接口 {0} 的条目里没有版本字段「{1}」（可用字段: {2}）；可能是接口变更，需要更新软件源' -f `
                $ApiUrl, $versionKey, (Get-JsonFieldNameText -Node $Chosen))
            return ''
        }
        return (Get-NormalizedVersionString -Value $found.Text)
    }
    $found = Get-VersionFromSourceText -Source $Source -Text $DownloadUrl -Where '下载地址'
    if (-not $found.Missing -and -not $found.Ok) { $Result.Error = [string]$found.Error }
    return [string]$found.Version
}
