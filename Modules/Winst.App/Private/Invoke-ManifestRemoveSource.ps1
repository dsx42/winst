#Requires -Version 5.1

function Invoke-ManifestRemoveSource {
    <#
    .SYNOPSIS
        删除一个软件源：先说明影响面并确认，再移除源列表条目与清单缓存。
    .DESCRIPTION
        供「管理软件源」的详情页使用。内置源与本地清单在这里就被挡住，不会走到删除。
        `--dry-run` 只打印将要删除什么；`--yes` 跳过确认。
    .OUTPUTS
        @{ Removed = <bool>; Cancelled = <bool>; Message }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Source
    )

    $result = @{ Removed = $false; Cancelled = $false; Message = '' }

    $name = [string]$Source['name']
    $isLocal = Get-EntryBool -Entry $Source -Key 'isLocal'
    $isBuiltin = Get-EntryBool -Entry $Source -Key 'isBuiltin'

    if ($isLocal -or $isBuiltin) {
        $result.Message = ('软件源 "{0}" 不能在这里删除（内置源 / 本地清单）。' -f $name)
        Write-Host ('  {0}' -f $result.Message) -ForegroundColor Yellow
        return $result
    }

    $dryRun = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun)
    Write-Host ''
    Write-Host ('  将删除软件源 "{0}" 及其清单缓存：' -f $name) -ForegroundColor Cyan
    Write-Host ('    源地址: {0}' -f [string]$Source['url']) -ForegroundColor Gray
    Write-Host '    已装软件不受影响；只是这个源里的软件不再出现在搜索 / 更新检查里。' -ForegroundColor DarkGray

    if ($dryRun) {
        Write-Host '  （预览）--dry-run 不落盘。' -ForegroundColor DarkYellow
        $result.Message = '（预览）未删除'
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
    $result.Message = [string]$r.Message
    Write-Host ''
    if ($r.Success) {
        $result.Removed = $true
        Write-Host ('  {0}' -f $result.Message) -ForegroundColor Green
    } else {
        Write-Host ('  {0}' -f $result.Message) -ForegroundColor Yellow
    }
    return $result
}
