#Requires -Version 5.1

function Invoke-WinstFluxServiceDownload {
    param([string]$Url, [string]$DestDir, [string]$FileName,
        [hashtable]$Headers, [string]$ProxyUrl, [string]$Version, [string]$ExpectedHash, [switch]$Restart,
        $Config, [string]$SizeText, [switch]$Quiet)

    $path = Get-WinstFluxTaskPath $DestDir $FileName
    $record = $null
    $id = ''
    if (Test-Path -LiteralPath $path) {
        $record = Get-Content -LiteralPath $path -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $id = [string]$record.taskId
    }
    try {
        if ($record) {
            if (-not $record.address -or $record.computer -ne [Environment]::MachineName) { throw '请在原计算机连接原管理服务' }
            $service = Get-WinstFluxService -Config $Config -Address $record.address -Reconnect
        } else {
            $service = Get-WinstFluxService -Config $Config
        }
    } catch {
        if (-not $record) { return @{ FallbackReason = $_.Exception.Message } }
        return @{ Ok = $false; FailureKind = 'ServiceUnavailable'
            Error = ('请重新连接原 FluxDown 服务，按 ID「{0}」或恢复记录 {1} 查询任务：{2}' -f $id, $path, $_.Exception.Message) }
    }

    # 只持久化请求凭据及代理配置的指纹；地址变化与否由原任务详情判断。
    $request = [ordered]@{ proxy = $ProxyUrl; cookie = [string]$Headers['Cookie']
        referer = [string]$Headers['Referer']; agent = [string]$Headers['User-Agent'] }
    $bytes = [Text.Encoding]::UTF8.GetBytes((ConvertTo-Json $request -Compress))
    $sha = [Security.Cryptography.SHA256]::Create()
    try { $fingerprint = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '') }
    finally { $sha.Dispose() }

    $task = $null
    $polling = $false
    $magnet = ([uri]$Url).Scheme -eq 'magnet'
    $saveDir = $DestDir
    try {
        if ($record) {
            $saveDir = Get-WinstFluxSaveDir $DestDir $FileName $record
            $task = Get-WinstOwnedFluxTask $service $record $DestDir $FileName
            $sameVersion = $record.version -ceq $Version
            $sameHash = $record.hash -eq $ExpectedHash
            $sameIdentity = $Version -and $ExpectedHash -and $sameVersion -and $sameHash
            if ($task -and $task.url -cne $Url -and -not $sameIdentity -and -not $Restart) {
                return @{ Ok = $false; FailureKind = 'RefreshSource'; Error = '下载地址已改变，需重新解析来源以确认文件身份' }
            }
            $missingFile = $false
            if ($task -and $task.status -eq 3) {
                if (-not (Test-WinstSafePathSegment -Name $task.fileName)) { throw '任务产物文件名无效' }
                $missingFile = -not (Test-Path -LiteralPath (Join-Path $saveDir $task.fileName) -PathType Leaf)
            }
            if (-not $task -or $missingFile -or (Get-EntryBool $record 'rejected') -or $Restart -or -not $sameVersion -or -not $sameHash) {
                Remove-WinstFluxTask $service $task $DestDir $FileName $record
                return Invoke-WinstFluxServiceDownload @PSBoundParameters
            }
        }
        $resume = [bool]$task
        if (-not $task) {
            $workId = [guid]::NewGuid().ToString('N')
            $saveDir = Join-Path $DestDir $workId
            Assert-WinstSafeWritePath -Path $saveDir -Directory
            $null = New-Item -ItemType Directory -Path $saveDir -ErrorAction Stop
            $record = [pscustomobject]@{ workId = $workId; computer = [Environment]::MachineName; address = $service.Address
                taskId = ''; magnet = $magnet; version = $Version; hash = $ExpectedHash; request = $fingerprint }
            Write-FileAtomic -Path $path -Content (ConvertTo-Json $record -Compress)
            $extra = @{}
            if ($Headers['Referer']) { $extra['Referer'] = [string]$Headers['Referer'] }
            $body = @{ url = $Url; saveDir = $saveDir; fileName = $FileName; startPaused = $true
                headers = $extra; cookies = [string]$Headers['Cookie']; userAgent = [string]$Headers['User-Agent']; proxyUrl = $ProxyUrl }
            $created = Invoke-WinstFluxApi $service POST 'tasks' $body
            $reason = Get-EntryString $created 'FallbackReason'
            if ($reason) {
                Remove-WinstFluxTask $service $null $DestDir $FileName $record
                return @{ FallbackReason = $reason }
            }
            $id = Get-EntryString $created 'taskId'
            if (-not $id) { throw '创建任务后未收到 ID，请在 FluxDown 核对暂存位置' }
            $record.taskId = $id
            Write-FileAtomic -Path $path -Content (ConvertTo-Json $record -Compress)
            $task = Get-WinstOwnedFluxTask $service $record $DestDir $FileName
            if (-not $task) { throw '未找到刚创建的任务' }
        }

        $id = [string]$task.taskId
        if (-not $record.taskId) {
            $record.taskId = $id
            Write-FileAtomic -Path $path -Content (ConvertTo-Json $record -Compress)
        }
        Write-WinstDownloadStart $FileName $SizeText 'FluxDown 桌面服务' -Resume:$resume -Quiet:$Quiet
        $route = 'tasks/' + $id
        $grace = 0
        if ($task.status -ne 3) {
            $changeUrl = $task.url -cne $Url
            $edit = $record.request -cne $fingerprint
            if (($changeUrl -or $edit) -and $task.status -notin @(2,4)) {
                $task = Suspend-WinstFluxTask $service $route
            }
            if ($changeUrl) { $null = Invoke-WinstFluxApi $service PUT ($route + '/url') @{ url = $Url } }
            if ($edit) {
                Set-WinstFluxTaskRequest $service $id $Headers $ProxyUrl
                $record.request = $fingerprint
                Write-FileAtomic -Path $path -Content (ConvertTo-Json $record -Compress)
            }
            $polling = $true
            if ($task.status -in @(2,4)) {
                $grace = 4
                $null = Invoke-WinstFluxApi $service PUT ($route + '/continue')
            }
        }
        while ($task.status -ne 3) {
            Start-Sleep -Milliseconds 500
            $task = Get-WinstOwnedFluxTask $service $record $DestDir $FileName
            if (-not $task) { throw '原任务在下载中被删除' }
            if ($grace -gt 0 -and $task.status -in @(2,4)) {
                $grace--
                continue
            }
            $grace = 0
            if ($task.status -in @(2,3,4)) { $polling = $false }
            if ($task.status -eq 2) {
                return @{ Ok = $false; FailureKind = 'Cancelled'; Error = ('FluxDown 任务 {0} 已暂停' -f $id) }
            }
            if ($task.status -eq 4) {
                $kind = Get-WinstFluxFailureKind -Message ([string]$task.errorMessage) -ReceivedBytes ([long]$task.downloadedBytes)
                return @{ Ok = $false; FailureKind = $kind; Error = ('FluxDown 任务 {0} 下载失败（{1}），可在服务中查看详情' -f $id, $kind) }
            }
            if ($task.status -notin @(0,1,3,5)) { throw '服务返回未知的任务状态' }
        }
        $polling = $false
        if (-not (Test-WinstSafePathSegment -Name $task.fileName)) { throw '任务产物文件名无效' }
        $actual = Join-Path $saveDir $task.fileName
        Assert-WinstSafeWritePath -Path $actual
        if (-not (Test-Path -LiteralPath $actual -PathType Leaf)) { throw '任务目录中缺少已完成的文件' }
        return @{ Ok = $true; Path = $actual; WorkDir = $saveDir; RecordPath = $path; Record = $record }
    } catch [Management.Automation.PipelineStoppedException] {
        throw
    } catch {
        $polling = $false
        $kind = 'Other'
        if ($_.Exception -is [Net.WebException]) { $kind = 'ServiceUnavailable' }
        return @{ Ok = $false; FailureKind = $kind
            Error = ('FluxDown 任务 {0} 未能完成，可按暂存路径 {1} 查询：{2}' -f $id, (Join-Path $saveDir $FileName), $_.Exception.Message) }
    } finally {
        # Ctrl+C 中断轮询时暂停原任务。即使失联，也保留 ID 供下一次查询。
        if ($polling -and $id) {
            try { $null = Suspend-WinstFluxTask $service $route }
            catch { Write-Warning ('请在 FluxDown 核对任务 {0} 是否已暂停：{1}' -f $id, $_.Exception.Message) }
        }
    }
}
