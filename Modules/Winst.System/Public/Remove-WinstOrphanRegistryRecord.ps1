#Requires -Version 5.1

function Remove-WinstOrphanRegistryRecord {
    <#
    .SYNOPSIS
        删除一条「卸载器文件已不存在」的系统安装记录。
    .DESCRIPTION
        用内层 MSI 卸掉某个版本后，外层引导包的记录会变成孤儿：显示在「设置 → 应用」里、
        卸载却因为程序文件已被清理而失败。这类记录已无任何可用信息，删掉它不会动任何程序文件。

        只允许删卸载记录分支下的键（KeyPath 来自注册表枚举，但脏数据不能拿去递归删除任意键）。
    .OUTPUTS
        @{ Ok; Skipped; Error }
    #>
    param([string]$KeyPath, [switch]$Quiet)

    $result = @{ Ok = $false; Skipped = $false; Error = '' }
    if (-not $KeyPath) { $result.Skipped = $true; return $result }
    if ($KeyPath -notmatch '(?i)\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\[^\\]+$') {
        $result.Skipped = $true
        $result.Error = ('不是系统安装记录里的键，已跳过: {0}' -f $KeyPath)
        return $result
    }
    if (-not (Test-Path -LiteralPath $KeyPath)) { $result.Skipped = $true; return $result }

    try {
        $displayName = ''
        $props = Get-ItemProperty -LiteralPath $KeyPath -ErrorAction SilentlyContinue
        if ($props) {
            $prop = $props.PSObject.Properties['DisplayName']
            if ($prop -and $null -ne $prop.Value) { $displayName = [string]$prop.Value }
        }
        Remove-Item -LiteralPath $KeyPath -Recurse -Force -ErrorAction Stop
        if (-not $Quiet) {
            if ($displayName) { Write-Host ('      已清理失效的安装记录: {0}' -f $displayName) -ForegroundColor DarkGray }
            else { Write-Host '      已清理一条失效的安装记录' -ForegroundColor DarkGray }
        }
        $result.Ok = $true
        return $result
    } catch {
        $result.Error = [string]$_.Exception.Message
        return $result
    }
}
