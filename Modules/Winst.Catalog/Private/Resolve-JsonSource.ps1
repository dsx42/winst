#Requires -Version 5.1

function Resolve-JsonSource {
    <#
    .SYNOPSIS
        解析 json 源：抓取 JSON 接口，按字段名取出条目、下载地址、版本号与校验信息。
    .DESCRIPTION
        面向「下载信息只在接口里」的站点（如 code.visualstudio.com/sha/ 这类返回 JSON 的下载信息接口）——
        页面不执行 JS，接口字段名直接写进清单即可：
          source.apiUrl     —— 接口地址（固定，不支持占位符；版本号由接口给出）；
          source.itemsKey   —— 条目（或条目数组）所在字段，缺省 = 整个响应就是一个条目；
          source.versionKey —— 版本字段（如 productVersion / version）；未声明时按 versionKind /
                               versionBetween 从下载地址里识别；
          files[0].urlKey   —— 主包下载地址的字段名（如 url / downloads.windowsZip.link），
                               可配 files[0].file（通配）在多个候选条目里挑出要下载的那一个；
          files[0].hashKey / files[0].hashFileKey —— sha256 摘要字段 / 校验文件地址字段。
        配套文件与其它来源一致：写完整地址（url，支持 {version}）+ dest。
        规格校验 / 取条目 / 选主包 / 定版本 / 落位各由独立函数承担。
    #>
    param([hashtable]$Context, $Entry)

    $result = New-SourceResolveResult -Kind 'json'

    $spec = Get-WinstJsonSourceSpec -Entry $Entry -Result $result
    if ($spec.Error) { $result.Error = $spec.Error; return $result }
    $source = $spec.Source
    $declared = @($spec.Declared)

    $itemsResult = Get-WinstJsonItems -Context $Context -Source $source -ApiUrl $spec.ApiUrl
    if ($itemsResult.Error) { $result.Error = $itemsResult.Error; return $result }
    $items = @($itemsResult.Items)

    $pick = Select-WinstJsonMainItem -Items $items -Declared $declared -MainLocator $spec.MainLocator `
        -FileRule $spec.FileRule -ApiUrl $spec.ApiUrl -Result $result
    if ($pick.Error) { $result.Error = $pick.Error; return $result }

    $version = Resolve-WinstJsonVersion -Source $source -Entry $Entry -Chosen $pick.Item -ApiUrl $spec.ApiUrl `
        -VersionKind $spec.VersionKind -VersionBetween $spec.VersionBetween -DownloadUrl $pick.Url -Result $result
    if ($result.Error) { return $result }
    $result.Version = $version

    $filesResult = New-WinstJsonResolvedFiles -Context $Context -Source $source -Entry $Entry -Declared $declared `
        -Chosen $pick.Item -DownloadUrl $pick.Url -Version $version -ApiUrl $spec.ApiUrl -Result $result
    if ($filesResult.Error) { $result.Error = $filesResult.Error; return $result }

    $result.Ok = $true
    $result.Files = @($filesResult.Files)
    return $result
}
