#Requires -Version 5.1

function Get-WinstLiveResolvedFileUrl {
    <#
    .SYNOPSIS
        实时重新解析某条目（跳过软件清单解析锁），取回指定文件当前的下载地址。
    .DESCRIPTION
        下载失败时的补救：部分来源给的地址带时效——`page` 源 `fetchWith: "browser"`
        的签名链接（约 1 天失效）、临时令牌地址等，解析锁里那份过期后必然下载失败。此时按条目所属来源
        （`-PreferSource`）实时重新解析一次拿新地址；只用于这一次下载重试，**不写回解析锁**
        （锁会在下次刷新软件源时统一更新）。
        取文件：优先按 `-Index` 序号对应，序号对不上时按文件名匹配。为避免「软件源已经换了新版本」时
        误把新版本的内容当成目标版本下载，调用方还要核对返回的 Name / Version 是否与本次目标一致
        （见 Invoke-WinstAppInstall 的下载阶段）。
    .OUTPUTS
        @{ Ok; Url; Name; Version; Error }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$PreferSource = '',
        [int]$Index = -1,
        [string]$FileName = ''
    )

    $result = @{ Ok = $false; Url = ''; Name = ''; Version = ''; Error = '' }

    $resolved = Get-WinstManifestAppPlan -Context $Context -Id $Id -PreferSource $PreferSource -LiveResolve
    if (-not $resolved.Ok) {
        $result.Error = [string]$resolved.Error
        return $result
    }

    $download = Get-EntryValue -Entry $resolved.Plan -Key 'download' -Default $null
    $files = @(Get-EntryArray -Entry $download -Key 'files')
    if ($files.Count -eq 0) {
        $result.Error = '软件源里没有可下载的文件'
        return $result
    }

    $file = $null
    if ($Index -ge 0 -and $Index -lt $files.Count) { $file = $files[$Index] }
    if (-not $file -and $FileName) {
        foreach ($candidate in $files) {
            $candidateName = Get-EntryString -Entry $candidate -Key 'name'
            if (-not $candidateName) { $candidateName = Get-FileNameFromUrl -Url (Get-EntryString -Entry $candidate -Key 'url') }
            if ($candidateName -ieq $FileName) { $file = $candidate; break }
        }
    }
    if (-not $file) {
        $result.Error = ('软件源里找不到对应的文件（{0}）' -f $FileName)
        return $result
    }

    $url = Get-EntryString -Entry $file -Key 'url'
    if (-not $url) {
        $result.Error = '软件源里这个文件没有下载地址'
        return $result
    }
    $name = Get-EntryString -Entry $file -Key 'name'
    if (-not $name) { $name = Get-FileNameFromUrl -Url $url }

    $result.Ok = $true
    $result.Url = $url
    $result.Name = $name
    $result.Version = Get-EntryString -Entry $resolved.Plan -Key 'version'
    return $result
}
