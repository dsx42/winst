#Requires -Version 5.1

function Invoke-WinstOldVersionCleanup {
    <#
    .SYNOPSIS
        「已装软件」详情里的 o) 清理旧版本：逐个向用户确认后移除本机并存的旧版本。
    .DESCRIPTION
        旧版本来自台账里的 `oldVersions`（修复扫描 / 安装后的版本检测登记），每条带一个卸载键路径：
        按这条记录运行官方卸载程序，只卸这一个版本，不碰同名的新版本。
        文件类检测只知道「还有这个版本的文件」，它的移除入口是按版本号反查出来的系统安装记录；
        两者都没有时（只剩遗留目录）如实告诉用户去「设置 → 应用」手动卸载。
        逐个确认，`n` 跳过但不影响其它条目；全部处理完后把台账里的 `oldVersions` 换成剩下的，
        用户下次进来看到的就是真实剩余状态。
    .OUTPUTS
        @{ Ok; Removed; Skipped; Failed; Notes }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Item
    )

    $result = @{ Ok = $true; Removed = @(); Skipped = @(); Failed = @(); Notes = @() }

    $id = [string]$Item['Id']
    $oldVersions = @($Item['OldVersions'])
    if ($oldVersions.Count -eq 0) { return $result }

    $displayName = [string]$Item['DisplayName']
    if (-not $displayName) { $displayName = $id }

    Write-Host ''
    Write-Host ('  「{0}」本机还并存这些旧版本：{1}' -f $displayName, (Format-WinstOldVersionText -OldVersions $oldVersions)) -ForegroundColor Cyan
    if (Test-WinstInputRedirected) {
        Write-Host '  当前输入被重定向（或非交互运行），无法逐个确认，本次不做任何卸载。' -ForegroundColor DarkYellow
        Write-Host '  请在菜单「已装软件」的详情里选 o) 清理旧版本。' -ForegroundColor DarkGray
        $result.Notes += '输入被重定向时清理旧版本需要交互确认，本次跳过'
        return $result
    }

    $remaining = @()
    foreach ($one in $oldVersions) {
        $version = [string]$one['Version']
        $recordKey = [string]$one['RecordKey']
        $detail = [string]$one['Detail']

        Write-Host ''
        Write-Host ('    旧版本 {0}' -f $version) -ForegroundColor White
        if ($detail) { Write-Host ('      {0}' -f $detail) -ForegroundColor DarkGray }

        if (-not $recordKey) {
            Write-Host '      检测时没能记下这个版本的卸载入口，现在按版本号重新查找系统安装记录 …' -ForegroundColor DarkGray
        }

        $delete = Read-WinstConfirm -Prompt ('    卸载这个旧版本？(y/N，默认保留)') -Default 'n'
        if (-not $delete) {
            $result.Skipped += $version
            $remaining += $one
            continue
        }

        # 同一个版本常有两层记录（外层引导包 + 内层 MSI），外层卸载器可能已被磁盘清理删掉：
        # 按「登记的键 → 其它可用的键」逐个尝试，不会连带卸掉同名的其它版本
        $run = Invoke-WinstOldVersionRemoval -Context $Context -Id $id -Version $version -RecordKey $recordKey -Quiet

        if (-not $run.Ok) {
            $result.Ok = $false
            $result.Failed += [ordered]@{ Version = $version; Error = [string]$run.Error }
            $remaining += $one
            Write-Host ('      失败: {0}' -f [string]$run.Error) -ForegroundColor Red
            continue
        }

        if ([bool]$run.NeedRestart) {
            $result.Notes += ('卸载 {0} 的旧版本 {1} 时提示需要重启电脑才能完成' -f $displayName, $version)
        }
        $result.Removed += $version
        Write-Host ('      已移除旧版本 {0}。' -f $version) -ForegroundColor Green
        foreach ($cleaned in @($run.Cleaned)) {
            $result.Notes += ('顺带清理了一条失效的安装记录（卸载程序已不存在），版本 {0}' -f $version)
        }
    }
    # 刷新系统快照：注册表卸载项 / 应用包都变了，后续检测必须重读
    Reset-WinstSystemCache

    # 台账里只留没清掉的旧版本：清完就写空数组，下次进来不再提醒
    $stateRead = Read-WinstState -InstallRoot $Context.InstallRoot
    if (-not $stateRead.Error) {
        $ledger = Get-WinstInstalledApp -State $stateRead.State -Id $id
        if ($ledger) {
            $kept = @()
            foreach ($one in @($remaining)) {
                $kept += [ordered]@{
                    version   = [string]$one['Version']
                    detail    = [string]$one['Detail']
                    recordKey = [string]$one['RecordKey']
                }
            }
            try {
                $null = Update-WinstInstalledAppFields -InstallRoot $Context.InstallRoot -Id $id -Entry $ledger `
                    -Fields @{ oldVersions = @($kept) }
            } catch {
                $result.Ok = $false
                $result.Notes += ('旧版本清理结果没能写回安装记录：{0}' -f $_.Exception.Message)
            }
        }
    }

    Write-Host ''
    $removedCount = @($result.Removed).Count
    $failedCount = @($result.Failed).Count
    if ($removedCount -gt 0) { Write-Host ('  已清理 {0} 个旧版本。' -f $removedCount) -ForegroundColor Green }
    if ($failedCount -gt 0) { Write-Host ('  有 {0} 个旧版本没能清理。' -f $failedCount) -ForegroundColor Red }
    if ($removedCount -eq 0 -and $failedCount -eq 0) { Write-Host '  没有清理任何旧版本。' -ForegroundColor DarkGray }
    foreach ($note in @($result.Notes)) { Write-Host ('  提示: {0}' -f $note) -ForegroundColor DarkYellow }

    return $result
}
