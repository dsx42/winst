#Requires -Version 5.1

function Invoke-WinstListShowCli {
    <#
    .SYNOPSIS
        CLI `bundle list [<file>]`：查看清单文件内容与各项状态。
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string]$Path = ''
    )

    $kindText = (Get-WinstListKindText)
    Write-Section 'winst bundle list'

    if (-not $Path) { return (Write-WinstListFileTable -Context $Context) }

    $target = Get-WinstListCommandTarget -Context $Context -Text $Path
    if (-not $target.Ok) {
        Write-Host ''
        Write-Host ('  {0}' -f $target.Error) -ForegroundColor Red
        return 1
    }

    $loaded = Get-WinstListItems -Context $Context -Path ([string]$target.Path)
    if (-not $loaded.Ok) {
        Write-Host ''
        Write-Host ('  {0}' -f $loaded.Error) -ForegroundColor Red
        return 1
    }
    if ($loaded.Warning) { Write-Host ('  提示: {0}' -f $loaded.Warning) -ForegroundColor DarkYellow }

    Write-Host ''
    Write-Host ('  {0}' -f [string]$target.Path) -ForegroundColor Gray
    if (-not $loaded.Exists) {
        Write-Host ('  这份{0}还不存在。' -f $kindText) -ForegroundColor Yellow
        return 1
    }
    if (@($loaded.Items).Count -eq 0) {
        Write-Host ('  {0}里还没有软件。' -f $kindText) -ForegroundColor Yellow
        return 0
    }

    $null = Show-WinstListContent -Context $Context -Items $loaded.Items
    return 0
}
