#Requires -Version 5.1

function Receive-WinstPackageFile {
    <#
    .SYNOPSIS
        下载文件并按失败原因刷新链接、等待重试，成功后交给缓存发布流程。
    #>
    param([hashtable]$Context, $Plan, $FilePlan, [string]$PkgDir, [string]$Id, [string]$SourceName,
        [int]$FileSeq, [hashtable]$Retry, [switch]$Bootstrap, [switch]$Quiet)

    $name = [string]$FilePlan['Name']
    $url = [string]$FilePlan['Url']
    $downloadDir = Join-WinstPath $PkgDir 'winst-download'
    try {
        Assert-WinstSafeWritePath -Path $downloadDir -Directory
        $null = New-Item -ItemType Directory -Path $downloadDir -Force -ErrorAction Stop
        $headers = Get-WinstPageDownloadHeaders -Context $Context -Plan $Plan -SourceName $SourceName -Id $Id -Index $FileSeq -Url $url
        if ($Retry.ContainsKey('Headers')) {
            $headers = $Retry['Headers']
            $Retry.Remove('Headers')
        }
        $refresh = $null -eq $headers -or [bool]$Retry['Refresh']
        $Retry.Remove('Refresh')
        $version = Get-EntryString -Entry $FilePlan['Decl'] -Key 'version'
        $expected = $Retry['Expected']
        $Retry.Remove('Expected')
        if (-not $expected -and -not $refresh) {
            $expected = Get-WinstExpectedHash -Context $Context -FileName $name -FileDecl $FilePlan['Decl'] -IgnoreCachedHash
            if (-not $expected.Ok) { return $expected }
        }
        $proxies = @(Get-WinstProxyAttempts -Context $Context -Download)
        while ($true) {
            $timer = [Diagnostics.Stopwatch]::StartNew()
            $sizeText = Format-WinstDownloadSizeText -Size $FilePlan['Size']
            $dl = $null
            if ($refresh) {
                try {
                    $live = Get-WinstLiveResolvedFileUrl -Context $Context -Id $Id -PreferSource $SourceName -Index $FileSeq -FileName $name
                    if (-not $live.Ok) { throw $live.Error }
                    $freshHash = Get-WinstExpectedHash -Context $Context -FileName $live.Name -FileDecl $live.File -IgnoreCachedHash
                    if (-not $freshHash.Ok) {
                        if (-not $freshHash.Network) { return $freshHash }
                        throw $freshHash.Error
                    }
                } catch {
                    $dl = @{ Ok = $false; FailureKind = 'Resolve'; Error = ('刷新下载链接失败：{0}' -f $_.Exception.Message) }
                }
                if (-not $dl) {
                    # 链接改变时用非空来源摘要确认文件身份，声明的版本也须匹配。
                    $sameFile = $expected -and $name -ieq $live.Name -and $version -ceq $live.Version -and
                        $Plan.version -ceq $live.Plan.version -and $expected.Hash -ieq $freshHash.Hash -and
                        ($url -ceq $live.Url -or $expected.Hash)
                    if (-not $sameFile) {
                        $Retry['Restart'] = [bool]$Retry['Restart'] -or ($expected -and $Retry['Attempts'] -gt 0)
                        $Retry['Headers'] = $live.Headers
                        $Retry['Expected'] = $freshHash
                        return @{ Ok = $false; RefreshPlan = $live.Plan }
                    }
                    $expected = $freshHash
                    $headers = $live.Headers
                    $url = $live.Url
                    $FilePlan['Decl'] = $live.File
                    if ($null -ne $live.Size) {
                        $FilePlan['Size'] = $live.Size
                        $sizeText = Format-WinstDownloadSizeText -Size $live.Size
                    }
                }
            }
            if (-not $dl) {
                $proxy = $proxies[[Math]::Min([int]$Retry['Attempts'], $proxies.Count - 1)]
                $request = @{
                    Context = $Context; Url = $url; DestDir = $downloadDir; FileName = $name
                    Headers = $headers; ProxyUrl = $proxy; Version = $version; ExpectedHash = $expected.Hash
                    SourceName = $SourceName; PackageVersion = [string]$Plan.version
                    Restart = [bool]$Retry['Restart']; Bootstrap = $Bootstrap
                    SizeText = $sizeText; Quiet = $Quiet
                }
                $timer.Restart()
                $dl = Invoke-WinstPackageDownload @request
                if ($dl['FailureKind'] -eq 'MissingEngine') {
                    $engine = Confirm-WinstDownloadEngine -Context $Context -Quiet:$Quiet
                    if (-not $engine.Ok) { return @{ Ok = $false; Error = ('下载引擎不可用：{0}' -f $engine.Error); Network = $true } }
                    $timer.Restart()
                    $dl = Invoke-WinstPackageDownload @request
                }
                $Retry.Remove('Restart')
            }
            $timer.Stop()
            $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            $attempt = '下载'
            if ($Retry['Attempts'] -gt 0) { $attempt = '第 {0} 次重试' -f $Retry['Attempts'] }
            $summary = '[{0}] {1}（{2}）{3}耗时 {4:F1} 秒' -f $stamp, $name, $sizeText, $attempt, $timer.Elapsed.TotalSeconds
            if ($dl.Ok) {
                if (-not $Quiet) { Write-Host ('    {0}，传输完成。' -f $summary) -ForegroundColor Gray }
                break
            }

            $kind = $dl['FailureKind']
            $errorText = $dl.Error
            $http = $kind -eq 'Http'
            $missing = $http -and $dl['StatusCode'] -eq 404
            if ($http -and $dl['StatusCode'] -in @(404, 410)) { $errorText = '这个地址找不到文件（HTTP {0}）：{1}。{2}' -f $dl['StatusCode'], $url, $dl.Error }
            elseif ($http -and $dl['StatusCode']) { $errorText = '文件服务器返回 HTTP {0}。{1}' -f $dl['StatusCode'], $dl.Error }
            $retryable = ($http -and -not $missing) -or $kind -in @('Resolve','RefreshSource','Interrupted') -or
                ($kind -eq 'Connect' -and -not $Retry['Connect'])
            if (-not $retryable -or $Retry['Attempts'] -ge 3) {
                return @{ Ok = $false; DownloadFailed = $kind -in @('Interrupted','Connect','Http')
                    Error = ('{0}，{1}' -f $summary, $errorText)
                    Cancelled = $kind -eq 'Cancelled'; Network = $kind -notin @('Disk','Cancelled','Other') }
            }
            if ($kind -eq 'Connect') { $Retry['Connect'] = $true }
            if ($kind -eq 'RefreshSource') { $Retry['Restart'] = $true }
            $refresh = $http -or $kind -in @('RefreshSource','Resolve') -or
                ($kind -eq 'Interrupted' -and $Plan.download.kind -eq 'page' -and ([uri]$url).Query.Length -gt 1)
            $Retry['Attempts']++
            $delay = 2 * $Retry['Attempts']
            if (-not $Quiet) {
                $next = '重试下载'
                if ($refresh) { $next = '刷新下载链接并重试' }
                Write-Host ('    {0}，{1}。{2} 秒后{3}（{4}/3）。' -f $summary, $errorText, $delay, $next, $Retry['Attempts']) -ForegroundColor DarkYellow
            }
            Start-Sleep -Seconds $delay
        }

        return (Publish-WinstPackageFile -Context $Context -FilePlan $FilePlan -Plan $Plan -SourceName $SourceName -Download $dl -Expected $expected -Url $url -DestDir $downloadDir)
    } catch {
        return @{ Ok = $false; Error = ('下载 {0} 失败：{1}' -f $name, $_.Exception.Message); Network = $false }
    }
}
