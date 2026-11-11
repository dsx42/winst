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

    $versionRule = Get-WinstVersionRule -Source $source
    if (-not $versionRule.Ok) { $result.Error = $versionRule.Error; return $result }
    $displayName = Get-MagnetDisplayName -Uri $primaryUrl
    $found = Get-VersionFromSourceText -Source $source -Text $displayName -Where '磁力链接的文件名（dn）'
    if ($found.Missing) {
        $result.Version = Get-NormalizedVersionString -Value (Get-EntryString -Entry $Entry -Key 'version')
    } elseif (-not $found.Ok) {
        $result.Error = [string]$found.Error
        return $result
    } else {
        $result.Version = [string]$found.Version
    }

    $files = @()
    $index = 0
    foreach ($item in $declared) {
        $index++
        $locator = Get-SourceFileLocator -Item $item -Kind 'magnet'
        if ($locator.Error) { $result.Error = $locator.Error; return $result }
        $uri = $locator.Url
        if (-not $uri -or $uri -notmatch '^(?i)magnet:') {
            $result.Error = ('source.files[{0}].url 必须是完整磁力链接' -f ($index - 1))
            return $result
        }
        if ($uri -cmatch '\{(?:version(?:Major|Minor)?|tag)\}') {
            $result.Error = ('source.files[{0}].url 的磁力链接不支持版本或 tag 占位符' -f ($index - 1))
            return $result
        }

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
