#Requires -Version 5.1

function Get-WinstDownloadCandidate {
    # 只探测原任务。已校验文件可在移动前后离线找回，交给发布流程复算摘要。
    param([string]$DestDir, [string]$FileName, $Record, $Config)

    try {
        if (-not (Test-WinstSafePathSegment -Name $FileName)) { throw '下载记录的文件名无效' }
        $dir = Get-WinstFluxSaveDir $DestDir $FileName $Record
        $name = [string](Get-EntryValue $Record 'actualName' -Default $FileName)
        $verified = Get-EntryString $Record 'verified'
        $needsHash = $false
        if (-not $verified) {
            if ((Get-EntryString $Record 'mode') -eq 'local') { throw '本地下载尚未确认完成' }
            if (-not $Record.address -or $Record.computer -ne [Environment]::MachineName) { throw '请在原计算机连接原管理服务' }
            $service = Get-WinstFluxService -Config $Config -Address $Record.address -Reconnect
            $task = Get-WinstOwnedFluxTask $service $Record $DestDir $FileName
            if ($task) {
                if ($task.status -notin @(2,3,4)) { throw 'FluxDown 任务尚未停止写入' }
                $name = [string]$task.fileName
            }
            $needsHash = -not $task -or $task.status -ne 3
            if ($needsHash -and -not (Get-EntryString $Record 'hash')) { throw '缺少可核实下载完成的来源摘要' }
        }
        if (-not (Test-WinstSafePathSegment -Name $name)) { throw '任务产物文件名无效' }
        $actual = Join-Path $dir $name
        Assert-WinstSafeWritePath -Path $actual
        $inPlace = $false
        if (-not (Test-Path -LiteralPath $actual -PathType Leaf -ErrorAction Stop)) {
            if (-not $verified) { throw '任务目录中尚无已完成文件' }
            $actual = Join-Path (Split-Path -Parent $DestDir) $FileName
            Assert-WinstSafeWritePath -Path $actual
            if (-not (Test-Path -LiteralPath $actual -PathType Leaf -ErrorAction Stop)) { throw '下载目录和缓存中均找不到已校验的文件' }
            $inPlace = $true
        }
        return @{ Ok = $true; Path = $actual; FileName = $FileName; WorkDir = $dir; InPlace = $inPlace
            NeedsHash = $needsHash; Record = $Record }
    } catch {
        return @{ Ok = $false; Error = $_.Exception.Message }
    }
}
