#Requires -Version 5.1

function Get-WinstShortcutInfo {
    <#
    .SYNOPSIS
        读取一个 .lnk 快捷方式的目标 / 起始位置。

    .DESCRIPTION
        快捷方式缺失或无法读取时返回 Ok = $false，供调用方判断是否需要修复。

    .OUTPUTS
        @{ Ok; TargetPath; WorkingDirectory }
    #>
    param(
        [Parameter(Mandatory = $true)][string]$LinkPath
    )

    $result = @{
        Ok               = $false
        TargetPath       = ''
        WorkingDirectory = ''
    }

    if (-not (Test-Path -LiteralPath $LinkPath -PathType Leaf)) { return $result }

    $shell = $null
    try {
        $shell = New-Object -ComObject WScript.Shell
        $lnk = $shell.CreateShortcut($LinkPath)
        $result.TargetPath = [string]$lnk.TargetPath
        $result.WorkingDirectory = [string]$lnk.WorkingDirectory
        $result.Ok = $true
    } catch {
    } finally {
        if ($shell) {
            try { [void][Runtime.InteropServices.Marshal]::ReleaseComObject($shell) } catch { }
        }
    }

    return $result
}
