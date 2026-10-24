#Requires -Version 5.1

function New-WinstPageResolvedFiles {
    <#
    .SYNOPSIS
        生成解析结果的文件列表：主包（可带页面提取的 hash）+ 第 2 条起的配套文件。
    .OUTPUTS
        @{ Error; Files }
    #>
    param($Context, $Source, $Item, $Declared, [string]$DownloadUrl, [string]$Version, [string]$PageHash, $Result)

    $resolvedFiles = @(New-ResolvedFileFromDeclaration -Item $Item -Url $DownloadUrl -Version $Version -MainFile -HashOverride $PageHash)
    if ($PageHash) {
        # hashFrom: "page" 是提取指令不是校验算法：解析结果里已带上提取到的 hash，把指令清掉，
        # 免得下游把它当校验文件算法处理
        try { $resolvedFiles[0]['hashFrom'] = '' } catch { }
    }

    # files[] 第 2 条起：配套文件（写成带 {version} 的完整地址 + dest），语义与其它来源一致；
    # 可选声明该文件自己的 versionRewrite / extract / stripTopDir
    $declaredList = @($Declared)
    for ($i = 1; $i -lt $declaredList.Count; $i++) {
        $extra = $declaredList[$i]
        $extraLocator = Get-SourceFileLocator -Item $extra -Kind 'page'
        if ($extraLocator.Error) { return @{ Error = [string]$extraLocator.Error; Files = $resolvedFiles } }
        if (-not $extraLocator.Url) {
            return @{ Error = '下载页来源除主包以外的文件要写完整地址（url，支持 {version}）；按页面提取地址只用于主包'; Files = $resolvedFiles }
        }
        $extraVersion = Get-WinstCompanionFileVersion -Context $Context -Item $extra -Source $Source -MainVersion $Version
        if (-not $extraVersion.Ok) { return @{ Error = [string]$extraVersion.Error; Files = $resolvedFiles } }
        foreach ($listedNote in @($extraVersion.Notes)) { $Result.Notes += [string]$listedNote }
        $extraUrl = Expand-VersionPlaceholder -Text $extraLocator.Url -Version $extraVersion.Version
        if ($extraUrl -match '\{version(Major)?\}') {
            return @{ Error = ('配套文件的下载地址里的版本号无法替换: {0}' -f $extraLocator.Url); Files = $resolvedFiles }
        }
        $extraDest = Get-EntryString -Entry $extra -Key 'dest'
        $resolvedFiles += New-ResolvedFileFromDeclaration -Item $extra -Url $extraUrl -Version $extraVersion.Version -Dest $extraDest
    }

    return @{ Error = ''; Files = $resolvedFiles }
}
