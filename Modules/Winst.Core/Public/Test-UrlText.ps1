#Requires -Version 5.1

function Test-UrlText {
    <#
    .SYNOPSIS
        判断文本是「地址」还是「文件名」：带协议（如 https://）的算地址，其余算文件名。
    #>
    param([string]$Text)

    if ($null -eq $Text) { return $false }
    return (([string]$Text).Trim() -match '^[A-Za-z][A-Za-z0-9+.\-]*://')
}
