#Requires -Version 5.1

function Remove-WinstShortcutFile {
    <#
    .SYNOPSIS
        删除一个 .lnk 快捷方式；不存在视为成功（幂等）。
    .OUTPUTS
        @{ Ok; Removed; Error }
    #>
    param([Parameter(Mandatory = $true)][string]$LinkPath)

    $result = @{ Ok = $false; Removed = $false; Error = '' }
    if (-not (Test-Path -LiteralPath $LinkPath -PathType Leaf)) { $result.Ok = $true; return $result }
    try {
        Remove-Item -LiteralPath $LinkPath -Force -ErrorAction Stop
        $result.Ok = $true
        $result.Removed = $true
    } catch {
        $result.Error = $_.Exception.Message
    }
    return $result
}
