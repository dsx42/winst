#Requires -Version 5.1

function Get-DataRoot {
    <#
    .SYNOPSIS
        返回数据根目录，默认 %USERPROFILE%\.winst\，可用 WINST_HOME 覆盖。
    #>
    if ($env:WINST_HOME -and $env:WINST_HOME.Trim()) {
        return [Environment]::ExpandEnvironmentVariables($env:WINST_HOME.Trim())
    }
    return (Join-Path $env:USERPROFILE '.winst')
}
