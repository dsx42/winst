#Requires -Version 5.1

function New-WinstJsonResolvedFiles {
    <#
    .SYNOPSIS
        ⑤ 落地：主包（含接口里的摘要 / 校验文件地址）+ 第 2 条起的配套文件。
    .OUTPUTS
        @{ Error; Files }
    #>
    param([hashtable]$Context, $Source, $Entry, $Declared, $Chosen, [string]$DownloadUrl, [string]$Version,
        [string]$ApiUrl, $Result, $FileItems, $HashFileRule)

    $skipCheck = Get-EntryBool -Entry $Source -Key 'skipExistsCheck'
    $files = @()
    $index = 0
    foreach ($item in @($Declared)) {
        $index++
        $locator = Get-SourceFileLocator -Item $item -Kind 'json'
        if ($locator.Error) { return @{ Error = [string]$locator.Error; Files = $files } }

        $dest = Get-WinstFileDest -Item $item -Index $index -Result $Result

        if ($index -eq 1) {
            $hash = ''
            $hashKey = (Get-EntryString -Entry $item -Key 'hashKey').Trim()
            if ($hashKey) {
                $found = Get-JsonNodeValue -Node $Chosen -Key $hashKey
                if (-not $found.Ok -or -not $found.Text) {
                    return @{ Error = ('JSON 接口 {0} 的条目里没有校验字段「{1}」；可能是接口变更，需要更新软件源' -f $ApiUrl, $hashKey); Files = $files }
                }
                $hash = ([string]$found.Text).Trim()
                if ($hash -notmatch '\A[0-9a-fA-F]+\z' -or -not (Get-HashAlgorithmFromDigestLength -Length $hash.Length)) {
                    return @{ Error = ('JSON 接口字段「{0}」必须是 32 / 40 / 64 / 128 位十六进制摘要' -f $hashKey); Files = $files }
                }
            }

            $hashFile = ''
            $hashFrom = ''
            $hashFileKey = (Get-EntryString -Entry $item -Key 'hashFileKey').Trim()
            if ($hashFileKey) {
                $found = Get-JsonNodeValue -Node $Chosen -Key $hashFileKey
                if (-not $found.Ok -or -not $found.Text) {
                    return @{ Error = ('JSON 接口 {0} 的条目里没有校验文件地址字段「{1}」；可能是接口变更，需要更新软件源' -f $ApiUrl, $hashFileKey); Files = $files }
                }
                $hashFile = ([string]$found.Text).Trim()
                $hashFrom = (Get-EntryString -Entry $item -Key 'hashFrom').Trim()
                if (-not $hashFrom) { $hashFrom = 'sha256sums' }
            }

            if ($HashFileRule) {
                foreach ($fileItem in @($FileItems)) {
                    $found = Get-JsonNodeValue -Node $fileItem -Key $locator.UrlKey
                    if (-not $found.Ok -or -not $found.Text) { continue }
                    $candidate = ([string]$found.Text).Trim()
                    if (-not (Test-FileRuleMatchesLink -Rule $HashFileRule -Text $candidate)) { continue }
                    if ($hashFile) {
                        return @{ Error = 'JSON 主包的 hashFileMatch 匹配到多个校验文件'; Files = $files }
                    }
                    $hashUri = $null
                    if (-not [Uri]::TryCreate($candidate, [UriKind]::Absolute, [ref]$hashUri) -or
                            @('http', 'https') -notcontains $hashUri.Scheme) {
                        return @{ Error = ('JSON 校验文件地址必须是绝对 HTTP(S) 地址：' + $candidate); Files = $files }
                    }
                    $hashFile = $candidate
                }
                if (-not $hashFile) {
                    return @{ Error = ('JSON 主包的 hashFileMatch 没有匹配到校验文件：' + $HashFileRule.Source); Files = $files }
                }
            }
            $urlProbe = Test-WinstManifestUrlOrNote -Context $Context -Url $DownloadUrl -Skip $skipCheck `
                -MissingError ('JSON 接口给出的地址不存在（HTTP 404）: {0}；可能是接口里的地址已失效' -f $DownloadUrl)
            if (-not $urlProbe.Ok) { return @{ Error = [string]$urlProbe.Error; Files = $files } }
            if ($urlProbe.Note) { $Result.Notes += [string]$urlProbe.Note }

            $files += New-ResolvedFileFromDeclaration -Item $item -Url $DownloadUrl -Version $Version `
                -HashOverride $hash -HashFileOverride $hashFile -HashFromOverride $hashFrom -MainFile
            continue
        }

        if (-not $locator.Url) {
            return @{ Error = 'JSON 接口来源里除主包以外的文件要写完整地址（url）；按接口字段取地址（urlKey）只用于主包'; Files = $files }
        }
        $fileVersion = Get-WinstCompanionFileVersion -Context $Context -Item $item -Source $Source -MainVersion $Version
        if (-not $fileVersion.Ok) { return @{ Error = [string]$fileVersion.Error; Files = $files } }
        foreach ($listedNote in @($fileVersion.Notes)) { $Result.Notes += [string]$listedNote }
        $files += New-ResolvedFileFromDeclaration -Item $item -Version $fileVersion.Version -Dest $dest `
            -OwnVersion ([bool]$fileVersion.Own) `
            -Url (Expand-VersionPlaceholder -Text $locator.Url -Version $fileVersion.Version)
    }

    return @{ Error = ''; Files = $files }
}
