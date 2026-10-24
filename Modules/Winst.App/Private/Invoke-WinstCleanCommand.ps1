#Requires -Version 5.1

function Invoke-WinstCleanCommand {
    <#
    .SYNOPSIS
        CLI：winst clean [<id>] —— 无参清理各 id 的旧版本包文件；指定 id 删除该 id 的全部已下载安装包。
    .DESCRIPTION
        范围，
        与下载成功后的自动清理同范围；指定 id = 删除该 id 的整个缓存目录并移除索引条目
        （与菜单「已下载包 → d」共用 `Remove-WinstCachedPackage`）。
    .OUTPUTS
        [int] 退出码：0 成功（含无旧包可清）/ 1 参数错误 / 3 部分删除失败
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string[]]$Arguments = @()
    )

    $ids = @()
    foreach ($token in @($Arguments)) {
        $text = [string]$token
        if (-not $text) { continue }
        if (Try-Apply-WinstCommonCliFlag -Text $text) { }
        elseif ($text -like '-*') {
            Write-Host ''
            Write-Host ('  未知参数: {0}' -f $text) -ForegroundColor Yellow
            Write-Host '  用法: winst clean [<id>]' -ForegroundColor Gray
            return 1
        } else {
            $ids += $text
        }
    }

    Write-Section 'clean'

    # —— 指定 id：删除该 id 的全部已下载安装包（与菜单「已下载包 → d」同一实现） ——
    if ($ids.Count -gt 0) {
        $failed = 0
        foreach ($id in $ids) {
            $one = Remove-WinstCachedPackage -Context $Context -Id $id
            if ($one.Ok) {
                Write-Host ('  {0}' -f [string]$one.Message) -ForegroundColor Green
            } else {
                Write-Host ('  失败: {0}' -f [string]$one.Error) -ForegroundColor Red
                $failed++
            }
        }
        if ($failed -gt 0) { return 3 }
        return 0
    }

    # —— 无参：清理各 id 的旧版本包文件（索引记录的那份保留） ——
    if (-not $Context.PkgDir) {
        Write-Host ''
        Write-Host '  没有可用的安装包位置。' -ForegroundColor Red
        return 1
    }
    $dryRun = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun)

    $cacheRead = Read-WinstCacheIndex -PkgDir $Context.PkgDir
    if ($cacheRead.Error) { Write-Host ('  提示: {0}' -f $cacheRead.Error) -ForegroundColor Yellow }
    $index = $cacheRead.Index

    $total = 0
    foreach ($key in @($index.Keys)) {
        $idText = [string]$key
        if (-not $idText) { continue }
        # 索引键同样会拼成 <pkgDir>\<id>：手工改过的 winst.json 里可能有 `..\` 之类的键
        if (-not (Test-WinstSafePathSegment -Name $idText)) {
            Write-Host ('  提示: 安装包索引里的条目名不合法，已跳过: {0}' -f $idText) -ForegroundColor DarkYellow
            continue
        }
        $keepFiles = @(Get-EntryArray -Entry $index[$key] -Key 'files')
        if ($keepFiles.Count -eq 0) { continue }   # 索引里没记录文件名时不猜、不动任何文件

        $candidates = New-Object 'System.Collections.Generic.List[string]'
        foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $Context.PkgDir $idText) -File -ErrorAction SilentlyContinue)) {
            if ($keepFiles -notcontains $file.Name) { $candidates.Add([string]$file.Name) }
        }
        if ($candidates.Count -eq 0) { continue }

        if ($dryRun) {
            $total += $candidates.Count
            Write-Host ('  （预览）{0}: 将删除 {1} 个旧版本文件' -f $idText, $candidates.Count) -ForegroundColor Gray
            continue
        }

        $removed = @(Remove-WinstOldPackages -Context $Context -Id $idText -KeepFiles $keepFiles)
        if ($removed.Count -eq 0) { continue }
        $total += $removed.Count
        $shown = ((@($removed) | Select-Object -First 3) -join '、')
        $moreText = ''
        if ($removed.Count -gt 3) { $moreText = ' …' }
        Write-Host ('  {0}: 已删除 {1} 个旧版本文件（{2}{3}）' -f $idText, $removed.Count, $shown, $moreText) -ForegroundColor Gray
    }

    Write-Host ''
    if ($total -eq 0) {
        Write-Host '  没有需要清理的旧版本安装包。' -ForegroundColor Green
    } elseif ($dryRun) {
        Write-Host ('  预览: 共 {0} 个旧版本安装包文件会被清理。' -f $total) -ForegroundColor Green
    } else {
        Write-Host ('  共清理 {0} 个旧版本安装包文件。' -f $total) -ForegroundColor Green
    }
    return 0
}
