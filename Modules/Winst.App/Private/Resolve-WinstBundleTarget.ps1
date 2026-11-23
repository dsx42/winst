#Requires -Version 5.1

function Resolve-WinstBundleTarget {
    <#
    .SYNOPSIS
        确定目标目录（未指定时交互输入，缺省落在数据根的 winst-kit）。
    .OUTPUTS
        [string] 目标目录绝对路径
    #>
    param([hashtable]$Context, [string]$TargetDir)

    if (-not $TargetDir) {
        $defaultTarget = Join-WinstPath $Context.DataRoot 'winst-kit'
        Write-Host ''
        Write-Host '  安装包将复制到这个目录（可以填 U 盘上的目录，如 E:\winst-kit）。' -ForegroundColor DarkGray
        Write-Host ('  直接回车 = {0}' -f $defaultTarget) -ForegroundColor DarkGray
        $text = Read-WinstAnswerText -Prompt '  请输入目标目录'
        if ($null -eq $text) { return '' }
        $text = $text.Trim('"')
        if (-not $text) { $text = $defaultTarget }
        $TargetDir = $text
    }
    if ($TargetDir -match '^[a-zA-Z]:(?![\\/])') { throw (New-Object System.ArgumentException('目标目录不能是盘符相对路径，请指定完整路径。')) }
    $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TargetDir)
    return [IO.Path]::GetFullPath($resolved)
}
