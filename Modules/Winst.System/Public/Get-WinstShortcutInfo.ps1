#Requires -Version 5.1

function Get-WinstShortcutInfo {
    <#
    .SYNOPSIS
        读取一个 .lnk 快捷方式的目标 / 起始位置 / 备注。

    .DESCRIPTION
        快捷方式是否存在由调用方先判断（`Test-Path -LiteralPath -PathType Leaf`）；
        本函数只负责把已有 .lnk 的内容读出来，供「已有快捷方式是否正确」的比对使用。
        读不出来（文件损坏、不是 .lnk、COM 不可用）时返回 Ok = $false 并带上原因，
        调用方据此决定是重建还是报错——不做静默猜测。

    .OUTPUTS
        @{ Ok; Exists; TargetPath; WorkingDirectory; Description; Error }
    #>
    param(
        [Parameter(Mandatory = $true)][string]$LinkPath
    )

    $result = @{
        Ok               = $false
        Exists           = $false
        TargetPath       = ''
        WorkingDirectory = ''
        Description      = ''
        Error            = ''
    }

    if (-not (Test-Path -LiteralPath $LinkPath -PathType Leaf)) { return $result }
    $result.Exists = $true

    $shell = $null
    try {
        $shell = New-Object -ComObject WScript.Shell
        $lnk = $shell.CreateShortcut($LinkPath)
        $result.TargetPath = [string]$lnk.TargetPath
        $result.WorkingDirectory = [string]$lnk.WorkingDirectory
        $result.Description = [string]$lnk.Description
        $result.Ok = $true
    } catch {
        $result.Error = $_.Exception.Message
    } finally {
        if ($shell) {
            try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell) } catch { }
        }
    }

    return $result
}
