#Requires -Version 5.1

function Get-WinstDuplicateDownloadNameError {
    <#
    .SYNOPSIS
        下载缓存使用平铺目录；所有产物文件名必须按 Windows 大小写规则唯一。
    #>
    param($Files)

    $names = New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($file in @($Files)) {
        $name = Get-EntryString -Entry $file -Key 'name'
        if (-not $name) { $name = Get-FileNameFromUrl -Url (Get-EntryString -Entry $file -Key 'url') }
        if (-not $name) { continue }
        if ($names.ContainsKey($name)) {
            return ('下载文件名重复：{0}；source.files 的产物必须使用不同文件名（不区分大小写），请修正 name 并刷新软件源。' -f $name)
        }
        $names[$name] = $true
    }
    return ''
}
