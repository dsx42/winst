#Requires -Version 5.1

function Write-WinstUpdateMissingEntry {
    <#
    .SYNOPSIS
        未安装的 id：按「仅下载类型 / 其它」给出引导文案（菜单与 CLI 两种口径）。
    .OUTPUTS
        @{ DownloadOnly }
    #>
    param([string]$Id, $RowById, [hashtable]$Result)

    $Result.NotInstalled++
    Write-Host ''
    # 仅下载类型的软件不写台账，它的「更新」是换新软件包，不该被引导去执行安装
    $isDownloadId = $false
    if ($RowById.Contains($Id)) {
        $firstSource = @($RowById[$Id]['Sources'])
        if ($firstSource.Count -gt 0) {
            $idType = ([string](Get-EntryString -Entry $firstSource[0]['Plan'] -Key 'type')).Trim().ToLowerInvariant()
            if ($idType -eq 'download') { $isDownloadId = $true }
        }
    }
    if ($isDownloadId) {
        if (Test-WinstMenuMode) {
            # 菜单里不出现命令行写法：指向菜单里能做这件事的地方
            Write-Host ('  {0}: 这是「仅下载软件包」类型的软件（不安装、没有安装记录）；它的软件包请到「软件列表」里下载 / 更新 / 删除。' -f $Id) -ForegroundColor Yellow
        } else {
            Write-Host ('  {0}: 这是「仅下载软件包」类型的软件（不安装、没有安装记录）：请用 winst download {0} 下载 / 更新软件包，winst clean {0} 删除软件包。' -f $Id) -ForegroundColor Yellow
        }
        return @{ DownloadOnly = $true }
    }
    if (Test-WinstMenuMode) {
        Write-Host ('  {0}: 安装记录里没有这个软件（未安装）。更新只对已安装的软件生效，安装请用「安装软件」。' -f $Id) -ForegroundColor Yellow
    } else {
        Write-Host ('  {0}: 安装记录里没有这个软件（未安装）。更新只对已安装的软件生效，安装请用「安装软件」/ winst install。' -f $Id) -ForegroundColor Yellow
    }
    return @{ DownloadOnly = $false }
}
