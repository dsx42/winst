#Requires -Version 5.1

function Invoke-WinstListShow {
    <#
    .SYNOPSIS
        显示选中清单的内容与状态。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string]$Path
    )

    $kindText = (Get-WinstListKindText)
    Write-Section ('查看' + $kindText)

    if (-not (Assert-WinstContext $Context)) { return }

    $targetPath = Resolve-WinstListTargetPath -Context $Context -Path $Path
    if (-not $targetPath) { return }

    $loaded = Get-WinstListItems -Context $Context -Path $targetPath -RefreshSources -ListOnly
    if (-not $loaded.Ok) {
        Write-Host ''
        Write-Host ('  {0}' -f $loaded.Error) -ForegroundColor Red
        return
    }
    if ($loaded.Warning) { Write-Host ('  提示: {0}' -f $loaded.Warning) -ForegroundColor DarkYellow }
    if (@($loaded.BadLines).Count -gt 0) {
        Write-Host ('  提示: 清单里有 {0} 行无法识别，编辑保存时会丢弃这些行。' -f @($loaded.BadLines).Count) -ForegroundColor DarkYellow
    }

    Write-Host ''
    Write-Host ('  {0}' -f $targetPath) -ForegroundColor Gray
    if (-not $loaded.Exists) {
        Write-Host ('  这个{0}还不存在（空的）。' -f $kindText) -ForegroundColor Yellow
        return
    }
    if (@($loaded.Items).Count -eq 0) {
        Write-Host ('  {0}里还没有软件。' -f $kindText) -ForegroundColor Yellow
        Write-Host ('  可到「高级功能 → 管理{0}」里编辑这份清单，挑选软件加入。' -f $kindText) -ForegroundColor DarkGray
        return
    }


    Write-Host ''
    Show-WinstListContent -Context $Context -Items $loaded.Items -StateRead $loaded.Lookup.StateRead
}
