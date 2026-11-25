#Requires -Version 5.1

function Get-WinstLiveResolvedFileUrl {
    <#
    .SYNOPSIS
        从同一软件源实时解析整个条目，返回当前文件的完整声明、安装计划与会话请求头。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$PreferSource,
        [int]$Index,
        [string]$FileName
    )

    $result = @{ Ok = $false; Url = ''; Name = ''; Version = ''; Error = '' }

    # 页面、版本接口和摘要响应都必须与本次取址同批刷新。
    (Get-WinstState -Name WinstHttpCache).Clear()
    $resolved = Get-WinstManifestAppPlan -Context $Context -Id $Id -RequiredSource $PreferSource -LiveResolve
    if (-not $resolved.Ok) {
        $result.Error = [string]$resolved.Error
        return $result
    }

    $download = Get-EntryValue -Entry $resolved.Plan -Key 'download' -Default $null
    $files = @(Get-EntryArray -Entry $download -Key 'files')
    if ($Index -lt 0 -or $Index -ge $files.Count) {
        $result.Error = ('刷新后的软件源中已没有文件 {0} 所在的位置（第 {1} 项）' -f $FileName, ($Index + 1))
        return $result
    }
    $file = $files[$Index]
    $url = Get-EntryString -Entry $file -Key 'url'
    if (-not $url) {
        $result.Error = '软件源里这个文件没有下载地址'
        return $result
    }
    $name = Get-EntryString -Entry $file -Key 'name'
    if (-not $name) { $name = Get-FileNameFromUrl -Url $url }

    $result.Plan = $resolved.Plan
    $result.File = $file
    $result.Size = Get-EntryValue -Entry $file -Key 'size'
    $result.Headers = Get-WinstPageDownloadHeaders -Context $Context -Plan $resolved.Plan -SourceName $resolved.Source -Id $Id -Index $Index -Url $url
    $result.Ok = $true
    $result.Url = $url
    $result.Name = $name
    $result.Version = Get-EntryString -Entry $file -Key 'version'
    return $result
}
