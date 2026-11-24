#Requires -Version 5.1

function Enter-WinstInstanceLock {
    <#
    .SYNOPSIS
        同时锁住数据目录和 Temp；任一锁被占用时返回失败与占用者信息。
    .DESCRIPTION
        以 FileAccess.ReadWrite / FileShare.Read 打开两个锁文件，允许读取占用者信息，
        拒绝其它实例写入。Temp 锁放在 .winst-stage 外，避免暂存清理影响锁。
        句柄及对应 Temp 保存在 WinstInstanceLock，业务与暂存清理结束后统一释放；
        申请失败时释放已取得的句柄，进程被强杀时由系统回收。
    .OUTPUTS
        @{ Ok; Busy; Path; OwnerPid; OwnerPath; OwnerStartedAt; Error }
    #>
    $path = Get-WinstInstanceLockPath
    $result = @{ Ok = $false; Busy = $false; Path = $Path; OwnerPid = 0; OwnerPath = ''; OwnerStartedAt = ''; Error = '' }
    if ($null -ne (Get-WinstState -Name WinstInstanceLock)) {
        $result.Error = '当前进程已经持有实例锁，不能重复申请'
        return $result
    }

    $streams = New-Object 'System.Collections.Generic.List[System.IO.FileStream]'
    try {
        $tempPath = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        foreach ($lockPath in @($Path, (Join-WinstPath $tempPath '.winst-stage.lock'))) {
            $result.Path = $lockPath
            Assert-WinstSafeWritePath -Path $lockPath
            $dir = Split-Path -Parent $lockPath
            if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
                $null = New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop
            }
            $stream = [IO.File]::Open($lockPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::Read)
            $streams.Add($stream)

            try {
                $lines = @(
                    ('pid={0}' -f $PID)
                    ('startedAt={0}' -f (Get-Date).ToString('s'))
                    ('path={0}' -f [string](Get-WinstState -Name WinstScriptPath))
                )
                $bytes = [Text.Encoding]::UTF8.GetBytes(($lines -join "`r`n") + "`r`n")
                $stream.SetLength(0)
                $stream.Write($bytes, 0, $bytes.Length)
                $stream.Flush()
            } catch {
                # 占用者信息仅用于诊断；写入失败不影响已取得的互斥句柄。
            }
        }
        $null = Set-WinstState -Name WinstInstanceLock -Value @{ Streams = $streams.ToArray(); TempRoot = $tempPath }
        $result.Ok = $true
        return $result
    } catch {
        $cause = $_.Exception.GetBaseException()
        $result.Busy = ($cause -is [IO.IOException] -and ($cause.HResult -band 0xffff) -in @(32,33))
        if ($result.Busy) {
            $owner = Read-WinstInstanceLockInfo -Path $result.Path
            $result.OwnerPid = [int]$owner.Pid
            $result.OwnerPath = [string]$owner.Path
            $result.OwnerStartedAt = [string]$owner.StartedAt
        }
        $result.Error = $_.Exception.Message
        return $result
    } finally {
        # 入口在申请失败时直接返回，不会进入业务的 finally。
        if (-not $result.Ok) {
            foreach ($stream in $streams) { $stream.Dispose() }
        }
    }
}
