#Requires -Version 5.1

function Resolve-WinstListFileForCli {
    <#
    .SYNOPSIS
        CLI 用：解析清单参数并确认清单文件确实存在；失败时直接打印提示（含可选的清单列表）。
    .DESCRIPTION
        `winst bundle install` / `winst bundle pack` 开头是同一段三步：解析参数 → 校验文件存在 →
        打印错误并返回 1。两处逐字相同，收敛到这里。

        返回 @{ Ok; Path; Name }，调用方只需 `if (-not $target.Ok) { return 1 }`。
        「解析失败」与「文件不存在」两种提示都在这里出，避免两边措辞漂移。
    .OUTPUTS
        @{ Ok; Path; Name }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string]$Text = ''
    )

    $target = Get-WinstListCommandTarget -Context $Context -Text $Text
    if (-not $target.Ok) {
        Write-Host ''
        Write-Host ('  {0}' -f $target.Error) -ForegroundColor Red
        return @{ Ok = $false; Path = ''; Name = '' }
    }
    if (-not (Test-Path -LiteralPath ([string]$target.Path) -PathType Leaf)) {
        Write-Host ''
        Write-Host ('  找不到安装清单: {0}' -f [string]$target.Path) -ForegroundColor Red
        $null = Write-WinstListFileTable -Context $Context
        return @{ Ok = $false; Path = ''; Name = '' }
    }
    return $target
}
