#Requires -Version 5.1

function New-ResolvedFileFromDeclaration {
    <#
    .SYNOPSIS
        按 files[] 条目的通用字段（name / dest / extract / stripTopDir / hash / hashFile / hashFrom / size）构造解析结果中的文件条目。
    .DESCRIPTION
        各来源解析器共用，使 files[] 的字段语义在 direct / github / listing / page / json / magnet 之间完全一致：
        先由解析器算出真实地址（或文件名），再统一挂上落位与校验信息。主包（第一条）不落 dest。
        校验文件未声明 hashFrom 时按 sha256sums 处理（即自动解析 SHA256SUMS 这类官方校验文件）。
        Hash / HashFile / HashFrom 三个 Override 供 json 源使用：这些值在清单里写不出具体内容，
        而是从接口字段（hashKey / hashFileKey）里取出来的，取到后覆盖清单声明。
    #>
    param(
        $Item,
        [Parameter(Mandatory = $true)][string]$Url,
        [string]$Version = '',
        [string]$Name = '',
        [string]$Dest = '',
        $Size = $null,
        [switch]$MainFile,
        [string]$HashOverride = '',
        [string]$HashFileOverride = '',
        [string]$HashFromOverride = ''
    )

    if ($MainFile) { $Dest = '' }

    # name 对全部来源生效：解析器没给固定名时取 files[] 里的 name（支持 {version}），
    # 用于地址里带不出来文件名的场合（如 download.php?file=… 这类跳转地址）
    if (-not $Name) {
        $Name = Expand-VersionPlaceholder -Text (Get-EntryString -Entry $Item -Key 'name') -Version $Version
    }

    $hashFile = Expand-VersionPlaceholder -Text (Get-EntryString -Entry $Item -Key 'hashFile') -Version $Version
    # {urlQuery:参数名}：从本文件解析出的下载地址查询串里取参数值（如校验接口与主包地址共享 file 参数），
    # 校验地址随解析结果自动更新，清单里无需重复版本号
    $hashFile = Expand-UrlQueryPlaceholder -Text $hashFile -Url $Url
    if ($HashFileOverride) { $hashFile = $HashFileOverride }
    $hashFrom = (Get-EntryString -Entry $Item -Key 'hashFrom').Trim()
    if ($HashFromOverride) { $hashFrom = $HashFromOverride }
    if ($hashFile -and -not $hashFrom) { $hashFrom = 'sha256sums' }

    $hash = Expand-VersionPlaceholder -Text (Get-EntryString -Entry $Item -Key 'hash') -Version $Version
    if ($HashOverride) { $hash = $HashOverride }

    # 附加文件可声明 extract（这个文件是压缩包，安装时解压到 dest 目录），
    # 可选再声明该压缩包自己的 stripTopDir
    $extract = Get-EntryBool -Entry $Item -Key 'extract'
    $stripTopDir = $null
    if ($extract) {
        $stripTopDir = ConvertTo-WinstStripTopDirValue `
            -Value (Get-EntryValue -Entry $Item -Key 'stripTopDir' -Default $null) -Default $false
    }

    $file = New-ResolvedFileItem -Url $Url -Name $Name -Dest $Dest `
        -Hash $hash `
        -HashFile $hashFile `
        -HashFrom $hashFrom `
        -Size $Size `
        -Extract:$extract `
        -StripTopDir $stripTopDir
    # 本文件自己的版本（独立取版的附加文件 = versionListUrl 解析出的版本；其余 = 主包版本）与
    # 比较项随文件记录携带，
    # 供下载规划（filePlan）与远端新鲜度提示读取
    $file['version'] = [string]$Version
    $compare = (Get-EntryString -Entry $Item -Key 'compare').Trim().ToLowerInvariant()
    if ($compare -ne 'size') { $compare = 'auto' }
    $file['compare'] = $compare
    # 新鲜度档位随文件记录携带：下载规划（Get-WinstFilePlan）读的是解析结果而不是清单原始条目，
    # 不在这里透传的话 files[].refresh / maxAgeHours 永远不会生效（一律退化为 auto + 168 小时）
    $refresh = (Get-EntryString -Entry $Item -Key 'refresh').Trim()
    if ($refresh) { $file['refresh'] = $refresh }
    $maxAgeHours = Get-EntryValue -Entry $Item -Key 'maxAgeHours' -Default $null
    if ($null -ne $maxAgeHours) { $file['maxAgeHours'] = $maxAgeHours }
    return $file
}
