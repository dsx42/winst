#Requires -Version 5.1

function Invoke-ManifestRemoveSource {
    <#
    .SYNOPSIS
        删除一个软件源：先说明影响面并确认，再移除源列表条目与清单缓存。
    .DESCRIPTION
        供「管理软件源」的详情页使用。详情页仅允许删除第三方软件源。
        `--dry-run` 只打印将要删除什么；`--yes` 跳过确认。
    .OUTPUTS
        @{ Removed = <bool>; Cancelled = <bool> }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Source
    )

    $result = @{ Removed = $false; Cancelled = $false }

    $name = [string]$Source['name']

    $dryRun = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun)
    Write-Host ''
    Write-Host ('  将删除软件源 "{0}" 及其清单缓存：' -f $name) -ForegroundColor Cyan
    Write-Host ('    源地址: {0}' -f [string]$Source['url']) -ForegroundColor Gray
    Write-Host '    已装软件不受影响；只是这个源里的软件不再出现在搜索 / 更新检查里。' -ForegroundColor DarkGray

    if ($dryRun) {
        Write-Host '  （预览）--dry-run 不落盘。' -ForegroundColor DarkYellow
        return $result
    }

    $yes = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Yes)
    if (-not $yes) {
        if (-not (Read-WinstConfirm -Prompt ('  确认删除？(y/N)') -Default 'n')) {
            Write-Host '  已取消：软件源没有改动。' -ForegroundColor DarkGray
            $result.Cancelled = $true
            return $result
        }
    }

    $r = Remove-RemoteManifest -Context $Context -Name $name
    Write-Host ''
    if ($r.Success) {
        $result.Removed = $true
        Write-Host ('  {0}' -f $r.Message) -ForegroundColor Green
    } else {
        Write-Host ('  {0}' -f $r.Message) -ForegroundColor Yellow
    }
    return $result
}
