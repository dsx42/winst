#Requires -Version 5.1

function Get-SourceFileDeclarations {
    <#
    .SYNOPSIS
        读取 source 的文件声明：files[] 数组（条目可写成对象，也可写成字符串 = 只给 url 的简写）。
    .DESCRIPTION
        支持以下文件声明写法（第一条 = 主包，各来源另行校验定位方式）：
          "files": [ "winst.ps1" ]                                  // 字符串简写
          "files": [ { "url": "winst.ps1" } ]                       // 只写地址 / 文件名
          "files": [ { "url": "https://…/{version}/x.zip", "hash": "…" } ]
        另支持 source.url（等价于只有一条 files[] 的主包简写）。
    #>
    param($Source)

    $hasFiles = $false
    $hasUrl = $false
    $fileValues = @()
    foreach ($pair in @(Get-WinstEntryPairs -Entry $Source)) {
        if ([string]$pair[0] -ieq 'files') { $hasFiles = $true; $fileValues = $pair[1] }
        if ([string]$pair[0] -ieq 'url') { $hasUrl = $true }
    }
    if ($hasFiles -and $hasUrl) { throw 'source.files 与 source.url 不能同时声明，请只保留 files 数组' }
    if ($hasFiles -and $null -eq $fileValues) {
        throw 'source.files 不能为 null，请填写文件数组'
    }

    $declared = @()
    $index = -1
    foreach ($item in @($fileValues)) {
        $index++
        if ($item -is [string]) {
            $text = ConvertTo-WinstTrimmedInput -Value $item
            if (-not $text) { throw ('source.files[{0}] 的地址不能为空' -f $index) }
            $declared += [ordered]@{ url = $text }
            continue
        }
        if ($null -eq $item -or ($item -isnot [System.Collections.IDictionary] -and $item -isnot [pscustomobject])) {
            throw ('source.files[{0}] 必须是文件对象或非空地址字符串' -f $index)
        }
        $declared += $item
    }
    if ($hasFiles) { return $declared }

    if ($hasUrl) {
        $single = Get-EntryValue -Entry $Source -Key 'url'
        if ($single -isnot [string] -or -not $single.Trim()) { throw 'source.url 必须是非空地址字符串' }
        return @([ordered]@{ url = $single.Trim() })
    }
    return @()
}
