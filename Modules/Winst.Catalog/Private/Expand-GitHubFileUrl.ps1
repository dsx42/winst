#Requires -Version 5.1

function Expand-GitHubFileUrl {
    <#
    .SYNOPSIS
        由仓库、发布 tag 与文件名拼出 GitHub 发布资产的标准下载地址。
    .DESCRIPTION
        让清单可以只写文件名（如 "winst.ps1" 或 "rufus-{version}.exe"），由 winst 补全
        https://github.com/<repo>/releases/download/<tag>/<文件名>，省掉一次「取资产列表」请求。
    #>
    param([string]$Repo, [string]$Tag, [string]$FileName)

    return ('https://github.com/{0}/releases/download/{1}/{2}' -f `
        $Repo, ([Uri]::EscapeDataString([string]$Tag)), ([Uri]::EscapeDataString([string]$FileName)))
}
