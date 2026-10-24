#Requires -Version 5.1

function Resolve-MagnetSource {
    <#
    .SYNOPSIS
        解析 magnet 源：不做占位符展开，版本从磁力链接的文件名（dn）按 versionKind / versionBetween 识别。
    #>
    param([hashtable]$Context, $Entry)

    $result = New-SourceResolveResult -Kind 'magnet'
    $source = Get-EntryValue -Entry $Entry -Key 'source' -Default $null
    $declared = @(Get-SourceFileDeclarations -Source $source)
    if ($declared.Count -eq 0) {
        $result.Error = '软件源里没有填写磁力链接（source.files）'
        return $result
    }

    $primaryLocator = Get-SourceFileLocator -Item $declared[0] -Kind 'magnet'
    if ($primaryLocator.Error) { $result.Error = $primaryLocator.Error; return $result }
    $primaryUrl = $primaryLocator.Url
    if (-not $primaryUrl) {
        if ($primaryLocator.File) {
            $result.Error = '磁力链接来源要填写完整的磁力链接（url），不能只写文件名（file）'
        } else {
            $result.Error = '软件源里的磁力链接为空'
        }
        return $result
    }
    if ($primaryUrl -notmatch '^(?i)magnet:') {
        $result.Error = ('这不是一个磁力链接: {0}' -f $primaryUrl)
        return $result
    }

    $versionKind = (Get-EntryString -Entry $source -Key 'versionKind').Trim()
    if ($versionKind -and -not (Get-VersionKindPattern -Kind $versionKind)) {
        $result.Error = ('不认识的版本识别器「{0}」；可用 {1}' -f $versionKind, ((Get-VersionKindList) -join '、'))
        return $result
    }
    $versionBetween = @(Get-EntryArray -Entry $source -Key 'versionBetween')

    if ($versionKind -or $versionBetween.Count -gt 0) {
        $displayName = Get-MagnetDisplayName -Uri $primaryUrl
        if ($displayName) {
            if ($versionBetween.Count -gt 0) {
                $between = Get-VersionBetween -Spec $versionBetween -Text $displayName
                if ($between.Ok) {
                    $result.Version = Get-NormalizedVersionString -Value $between.Value
                } else {
                    $result.Notes += ('未能从文件名「{0}」里取出 {1} 之间的内容作为版本号' -f $displayName, ($versionBetween -join ' … '))
                }
            } else {
                $found = Get-VersionValue -Text $displayName -Kind $versionKind
                if ($found) {
                    $result.Version = Get-NormalizedVersionString -Value $found
                } else {
                    $result.Notes += ('未能从磁力链接的文件名（{0}）中识别出版本号' -f $displayName)
                }
            }
        } else {
            $result.Notes += '磁力链接里没有文件名信息，无法识别版本号'
        }
    }
    if (-not $result.Version) {
        $result.Version = Get-NormalizedVersionString -Value (Get-EntryString -Entry $Entry -Key 'version')
    }

    $files = @()
    $index = 0
    foreach ($item in $declared) {
        $index++
        $locator = Get-SourceFileLocator -Item $item -Kind 'magnet'
        if ($locator.Error) { $result.Error = $locator.Error; return $result }
        $uri = $locator.Url
        if (-not $uri) { continue }

        $fileName = Get-EntryString -Entry $item -Key 'name'
        if (-not $fileName) { $fileName = Get-MagnetDisplayName -Uri $uri }

        $size = $null
        $xl = Get-MagnetParameter -Uri $uri -Name 'xl'
        $bytes = 0L
        if ($xl -and [long]::TryParse($xl, [ref]$bytes)) { $size = $bytes }

        $dest = Get-WinstFileDest -Item $item -Index $index -Result $result
        $files += New-ResolvedFileFromDeclaration -Item $item -Url $uri -Dest $dest -Name $fileName -Size $size
    }

    $result.Ok = $true
    $result.Files = $files
    return $result
}
