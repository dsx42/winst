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
        @{ Cancelled; Updated; Failed }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Item
    )

    $id = [string]$Item['Id']

    Write-Host ''
    Write-Host ('  —— 更新 {0} ——' -f [string]$Item['DisplayName']) -ForegroundColor Cyan
    Write-Host ('    这次可以单独选更新方式与软件源；回车 = 不改，按默认方式更新（默认方式: {0}）。' -f (Get-WinstUpdateModeName -Context $Context)) -ForegroundColor DarkGray

    $mode = Select-WinstUpdateMode
    if (-not $mode.Ok) { return @{ Cancelled = $true; Updated = 0; Failed = 0 } }

    $origin = Get-EntryString -Entry $Item['Ledger'] -Key 'manifestOrigin'
    $source = Select-WinstUpdateSource -Row $Item['Row'] -OriginName $origin
    if (-not $source.Ok) {
        if ($source.Error) { Write-Host ('  {0}' -f $source.Error) -ForegroundColor Yellow }
        return @{ Cancelled = $true; Updated = 0; Failed = 0 }
    }

    $sourceVersion = [string]$source.Entry['Version']
    $installed = [string]$Item['RawVersion']
    $force = $false
    Write-Host ''
    if (Test-WinstRowVersionFromPackage -Row $Item['Row'] -Chosen $source.Entry) {
        if ((Get-EntryString -Entry $source.Entry['Plan'] -Key 'remoteFresh') -ine 'unchanged') {
            Write-Host '  将取包核对版本，再决定是否更新。' -ForegroundColor DarkYellow
        }
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
        Force = $force
    }
    if ($mode.Mode -eq 'full') { $params['ForceSystemItems'] = $true }
    else { $params['FilesOnly'] = $true }
    $updated = Invoke-WinstUpdateTargets @params

    # 保留实际更新 / 跳过 / 失败计数；执行阶段取消不会再触发默认更新。
    $mapped = ConvertFrom-WinstUpdateTargetsResult -Result $updated
    if ($mapped.Error) {
        Write-Host ''
        Write-Host ('  {0}' -f $mapped.Error) -ForegroundColor Red
    }
    return $mapped
}
