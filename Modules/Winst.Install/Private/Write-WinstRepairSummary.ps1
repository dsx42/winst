#Requires -Version 5.1

function Write-WinstRepairSummary {
    <#
    .SYNOPSIS
        汇总输出（Quiet 模式一行结论；否则逐项列出）。返回退出码 0。
    #>
    param([hashtable]$Context, $State, [switch]$Quiet, [switch]$DryRun, [bool]$Saved, [hashtable]$Counters,
        [int]$LedgerBefore, [string]$IndexNote, $MissingDirs)

    $added = [int]$Counters.Added
    $filled = [int]$Counters.Filled
    $updated = [int]$Counters.Updated
    $kept = [int]$Counters.Kept
    $dirOnlyAdded = [int]$Counters.DirOnlyAdded
    $missing = @($MissingDirs)

    $ledgerAfter = @($State['Installed'].Keys).Count
    Write-Host ''
    if ($Quiet) {
        # 内嵌调用（进入「已装软件」列表时）：只给一行结论，改动细节已在上面逐条打印
        $quietParts = @()
        if ($added -gt 0) { $quietParts += ('新增 {0}' -f $added) }
        if ($updated -gt 0) { $quietParts += ('更正 {0}' -f $updated) }
        if ($filled -gt 0) { $quietParts += ('补全 {0}' -f $filled) }
        if ($DryRun) {
            Write-Host ('  安装记录: 预览模式，未写入（共 {0} 条）' -f $LedgerBefore) -ForegroundColor DarkYellow
        } elseif ($Saved) {
            Write-Host ('  安装记录已刷新: {0}（共 {1} 条）' -f ($quietParts -join ' / '), $ledgerAfter) -ForegroundColor Gray
        } else {
            Write-Host ('  安装记录: 共 {0} 条，本次无改动' -f $LedgerBefore) -ForegroundColor DarkGray
        }
        if ($missing.Count -gt 0) {
            Write-Host ('  提示: {0} 条记录的安装目录已不存在（未删除记录，可到「已装软件」里查看或卸载）' -f $missing.Count) -ForegroundColor DarkYellow
        }
        return 0
    }

    Write-Host '  修复完成' -ForegroundColor Green
    Write-Host ('    安装记录位置 : {0}' -f (Get-WinstStatePath -InstallRoot $Context.InstallRoot)) -ForegroundColor DarkGray
    Write-Host ('    新增登记     : {0} 条' -f $added) -ForegroundColor Gray
    if ($dirOnlyAdded -gt 0) {
        Write-Host ('      其中仅按目录登记: {0} 条（清单里没有对应软件，版本 / 类型未知）' -f $dirOnlyAdded) -ForegroundColor DarkGray
    }
    Write-Host ('    与记录一致   : {0} 条（未改动）' -f $kept) -ForegroundColor Gray
    Write-Host ('    更正版本     : {0} 条（记录里的版本与本次识别结果不一致时更正）' -f $updated) -ForegroundColor Gray
    Write-Host ('    补全版本     : {0} 条' -f $filled) -ForegroundColor Gray
    Write-Host ('    安装记录条数 : 修复前 {0} 条 → 修复后 {1} 条' -f $LedgerBefore, $ledgerAfter) -ForegroundColor Gray
    Write-Host ('    缓存索引     : {0}' -f $IndexNote) -ForegroundColor Gray

    if ($missing.Count -gt 0) {
        Write-Host ('    目录缺失的条目: {0} 个（未删除记录、未清理系统项；请按需重新安装 / 更新 / 卸载）' -f $missing.Count) -ForegroundColor DarkYellow
        foreach ($item in $missing) {
            Write-Host ('        {0}  {1}' -f $item['Id'], $item['InstallDir']) -ForegroundColor DarkGray
        }
    }
    Write-Host ''
    if ($DryRun) {
        Write-Host '  预览模式：未做任何修改。' -ForegroundColor DarkYellow
    } elseif ($Saved) {
        Write-Host '  安装记录已保存。' -ForegroundColor DarkGray
    } else {
        Write-Host '  安装记录无需修改。' -ForegroundColor DarkGray
    }
    return 0
}
