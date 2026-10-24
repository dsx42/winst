#Requires -Version 5.1

function Get-SourceFileDeclarations {
    <#
    .SYNOPSIS
        读取 source 的文件声明：files[] 数组（条目可写成对象，也可写成字符串 = 只给 url 的简写）。
    .DESCRIPTION
        三种等价写法（全部来源通用，第一条 = 主包）：
          "files": [ "winst.ps1" ]                                  // 字符串简写
          "files": [ { "url": "winst.ps1" } ]                       // 只写地址 / 文件名
          "files": [ { "url": "https://…/{version}/x.zip", "hash": "…" } ]
        另支持 source.url（等价于只有一条 files[] 的主包简写）。
    #>
    param($Source)

    $declared = @()
    foreach ($item in @(Get-EntryArray -Entry $Source -Key 'files')) {
        if ($null -eq $item) { continue }
        if ($item -is [string]) {
            $text = ConvertTo-WinstTrimmedInput -Value $item
            if ($text) { $declared += [ordered]@{ url = $text } }
            continue
        }
        $declared += $item
    }
    if ($declared.Count -gt 0) { return $declared }

    $single = Get-EntryString -Entry $Source -Key 'url'
    if ($single) { return @([ordered]@{ url = $single }) }
    return @()
}
