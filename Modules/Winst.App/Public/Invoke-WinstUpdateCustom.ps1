#Requires -Version 5.1

function Invoke-WinstUpdateCustom {
    <#
    .SYNOPSIS
        「已装软件 → c」单独更新，以及「检查更新」里单独选更新方式与软件源：
        本次单独选择更新方式与软件源，不改变「设置 → 更新方式」（中途回车 / `b` 由调用方回退为按默认更新）。
    .DESCRIPTION
        - 更新方式：只更新文件（环境变量 / PATH 保持原样，快捷方式只修正不新建）/ 完整更新（覆盖已存在项）。
        - 软件源：从该软件可用的来源里选择（标出安装时用的来源）；所选来源版本不比本机新时按强制安装处理
          （相同版本 = 重装一次，更低版本 = 降级覆盖），执行前仍有安装流程的确认提示。
    .OUTPUTS
        @{ Ok; Cancelled; Mode; Source; ExitCode; Error }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Item
    )

    $result = @{ Ok = $false; Cancelled = $false; Mode = ''; Source = '' }
    $id = [string]$Item['Id']

    if (-not $Item['Row']) {
        Write-Host ''
        Write-Host ('  软件源里没有「{0}」，无法单独选更新方式与来源；可到「高级功能 → 管理软件源」刷新软件源后重试。' -f [string]$Item['DisplayName']) -ForegroundColor Yellow
        $result.Cancelled = $true
        return $result
    }

    Write-Host ''
    Write-Host ('  —— 更新 {0} ——' -f [string]$Item['DisplayName']) -ForegroundColor Cyan
    Write-Host ('    这次可以单独选更新方式与软件源；回车 = 不改，按默认方式更新（默认方式: {0}）。' -f (Get-WinstUpdateModeName -Context $Context)) -ForegroundColor DarkGray

    $mode = Select-WinstUpdateMode
    if (-not $mode.Ok) { $result.Cancelled = $true; return $result }

    $origin = Get-EntryString -Entry $Item['Ledger'] -Key 'manifestOrigin'
    $source = Select-WinstUpdateSource -Row $Item['Row'] -OriginName $origin
    if (-not $source.Ok) {
        if ($source.Error) { Write-Host ('  {0}' -f $source.Error) -ForegroundColor Yellow }
        $result.Cancelled = $true
        return $result
    }

    $sourceVersion = [string]$source.Entry['Version']
    $installed = [string]$Item['RawVersion']
    $force = $false
    Write-Host ''
    # 版本号取自主包文件信息的条目：所选来源的「版本」其实来自缓存里那份包，不能据此判「同版本 / 更低版本」，
    # 交给安装流程「先取包、再决定」
    if (Test-WinstRowVersionFromPackage -Row $Item['Row']) {
        Write-Host '  版本号取自主包文件信息：本次会重新取包核对版本，再决定是更新还是跳过。' -ForegroundColor DarkYellow
    } elseif ($installed -and $sourceVersion) {
        $cmp = Compare-WinstVersion -A $sourceVersion -B $installed
        if ($cmp -eq 0) {
            $force = $true
            Write-Host ('  所选来源「{0}」的版本与本机相同（{1}）：将强制重装一次。' -f $source.Source, $sourceVersion) -ForegroundColor DarkYellow
        } elseif ($cmp -lt 0) {
            $force = $true
            Write-Host ('  所选来源「{0}」的版本 {1} 低于本机 {2}：将按强制安装处理（会覆盖现有文件）。' -f $source.Source, $sourceVersion, $installed) -ForegroundColor DarkYellow
        }
    }
    Write-Host ('  本次更新方式: {0}    软件源: {1}' -f (Get-WinstUpdateModeText -Mode $mode.Mode), $source.Source) -ForegroundColor Gray

    $params = @{
        Context = $Context; Ids = @($id); SourceName = $source.Source;
        Force = $force; AutoPickSource = $true
    }
    if ($mode.Mode -eq 'full') { $params['ForceSystemItems'] = $true }
    $updated = Invoke-WinstUpdateTargets @params

    # 结果必须如实透传：之前无条件置 Ok=$true，下载 / 校验失败也会被当成「更新成功」
    $mapped = ConvertFrom-WinstUpdateTargetsResult -Result $updated -Mode $mode.Mode -Source $source.Source
    if (-not $mapped.Ok -and $mapped.Error) {
        Write-Host ''
        Write-Host ('  {0}' -f $mapped.Error) -ForegroundColor Red
    }
    return $mapped
}
