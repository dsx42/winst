#Requires -Version 5.1

function Receive-WinstPackageFile {
    <#
    .SYNOPSIS
        按文件重试，在任务目录中校验产物后原子发布到缓存。
    #>
    param([hashtable]$Context, $Plan, $FilePlan, [string]$PkgDir, [string]$Id, [string]$SourceName,
        [int]$FileSeq, $PrevEntry, [hashtable]$Retry, [switch]$Bootstrap, [switch]$Quiet)

    $name = [string]$FilePlan['Name']
    $url = [string]$FilePlan['Url']
    $commitTarget = [string]$FilePlan['Target']
    $downloadDir = Join-WinstPath $PkgDir 'winst-download'
    try {
        Assert-WinstSafeWritePath -Path $downloadDir -Directory
        $null = New-Item -ItemType Directory -Path $downloadDir -Force -ErrorAction Stop
        $headers = Get-WinstPageDownloadHeaders -Context $Context -Plan $Plan -SourceName $SourceName -Id $Id -Index $FileSeq -Url $url
        if ($Retry.ContainsKey('Headers')) {
            $headers = $Retry['Headers']
            $Retry.Remove('Headers')
        }
        $refresh = $null -eq $headers
        $afterFailure = $false
        $version = Get-EntryString -Entry $FilePlan['Decl'] -Key 'version'
        $expected = $Retry['Expected']
        $Retry.Remove('Expected')
        if (-not $expected -and -not $refresh) {
            $expected = Get-WinstExpectedHash -Context $Context -FileName $name -FileDecl $FilePlan['Decl'] -IgnoreCachedHash
            if (-not $expected.Ok) { return $expected }
        }
        $proxies = @(Get-WinstProxyAttempts -Context $Context -Download)
        while ($true) {
            if ($refresh) {
                $live = Get-WinstLiveResolvedFileUrl -Context $Context -Id $Id -PreferSource $SourceName -Index $FileSeq -FileName $name
                if (-not $live.Ok) { return @{ Ok = $false; Error = ('重新解析 {0} 失败：{1}' -f $name, $live.Error); Network = $true } }
                $freshHash = Get-WinstExpectedHash -Context $Context -FileName $live.Name -FileDecl $live.File -IgnoreCachedHash
                if (-not $freshHash.Ok) { return $freshHash }

                # 只有文件身份明确时才能将旧分段用于新的请求。
                $sameFile = $expected -and $name -ieq $live.Name -and $version -ceq $live.Version -and
                    $Plan.version -ceq $live.Plan.version -and $expected.Hash -ieq $freshHash.Hash -and
                    ($url -ceq $live.Url -or ($version -and $expected.Hash))
                if (-not $sameFile) {
                    if ($name -ine $live.Name) {
                        Reset-WinstPackageDownload -DestDir $downloadDir -FileName $name -Config $Context.Config
                    }
                    $Retry['Restart'] = $afterFailure
                    $Retry['Headers'] = $live.Headers
                    $Retry['Expected'] = $freshHash
                    return @{ Ok = $false; RefreshPlan = $live.Plan }
                }
                $expected = $freshHash
                $headers = $live.Headers
                $url = $live.Url
                $FilePlan['Decl'] = $live.File
                $FilePlan['Size'] = $live.Size
            }
            if ($Retry['Attempts'] -ge 4) { throw ('{0} 已达到每个文件最多三次重试的限制' -f $name) }
            $proxy = $proxies[[Math]::Min([int]$Retry['Attempts'], $proxies.Count - 1)]
            $request = @{
                Context = $Context; Url = $url; DestDir = $downloadDir; FileName = $name
                Headers = $headers; ProxyUrl = $proxy; Version = $version; ExpectedHash = $expected.Hash
                Restart = [bool]$Retry['Restart']; Bootstrap = $Bootstrap
                SizeText = Format-WinstDownloadSizeText -Size $FilePlan['Size']; Quiet = $Quiet
            }
            $dl = Invoke-WinstPackageDownload @request
            if ($dl['FailureKind'] -eq 'MissingEngine') {
                $engine = Confirm-WinstDownloadEngine -Context $Context -Quiet:$Quiet
                if (-not $engine.Ok) { return @{ Ok = $false; Error = ('下载引擎不可用：{0}' -f $engine.Error); Network = $true } }
                $dl = Invoke-WinstPackageDownload @request
            }
            if ($dl['FailureKind'] -eq 'RefreshSource') {
                # 记录的旧任务与当前地址身份不符，重新取址成功前保留现场。
                $refresh = $true
                $afterFailure = $true
                $Retry['Restart'] = $true
                continue
            }
            $Retry['Attempts']++
            $Retry.Remove('Restart')
            if ($dl.Ok) { break }

            $kind = $dl['FailureKind']
            $pageQuery = $Plan.download.kind -eq 'page' -and ([uri]$url).Query.Length -gt 1
            $canRetry = ($kind -eq 'Interrupted') -or ($kind -eq 'Connect' -and -not $Retry['Connect']) -or
                ($kind -eq 'Auth' -and $pageQuery -and -not $Retry['Auth'])
            if (-not $canRetry -or $Retry['Attempts'] -ge 4) {
                return @{ Ok = $false; DownloadFailed = $kind -in @('Interrupted','Connect','Auth','Http')
                    Error = ('下载 {0} 失败：{1}' -f $name, $dl.Error)
                    Cancelled = $kind -eq 'Cancelled'; Network = $kind -notin @('Disk','Cancelled','Other') }
            }
            $Retry[$kind] = $true
            $afterFailure = $true
            $refresh = $pageQuery -and $kind -in @('Interrupted','Auth')
            if (-not $Quiet) { Write-Host ('    {0}，正在重试 {1}（{2}/3）…' -f $dl.Error, $name, $Retry['Attempts']) -ForegroundColor DarkYellow }
        }

        $target = $dl.Path
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw ('下载完成后没有找到文件：' + $target) }
        Assert-WinstSafeWritePath -Path $target
        $check = Test-WinstFileIntegrity -FilePath $target -Expected $expected
        if (-not $check.Ok) {
            $retained = Reject-WinstPackageDownload -Download $dl
            return @{ Ok = $false; Error = ('{0} 校验失败：{1}。暂存位置：{2}' -f $name, $check.Error, $retained); Network = $false }
        }

        Clear-WinstReplacedPackageRecord -PkgDir $Context.PkgDir -Id $Id -Entry $PrevEntry -Name $name -Main:($FileSeq -eq 0)
        Assert-WinstSafeWritePath -Path $commitTarget
        if (Test-Path -LiteralPath $commitTarget -PathType Leaf) {
            [IO.File]::Replace($target, $commitTarget, [System.Management.Automation.Language.NullString]::Value)
        } else {
            [IO.File]::Move($target, $commitTarget)
        }
        if ($FilePlan['Url'] -cne $url) {
            $FilePlan['CheckedAt'] = ''
            $FilePlan['ValidatorETag'] = ''
            $FilePlan['ValidatorLastModified'] = ''
        }
        if (-not $FilePlan['CheckedAt']) {
            Set-WinstFilePlanValidators -Plan $FilePlan -Context $Context -Uri $url -RequireFields
        }
        $FilePlan['Url'] = $url
        Set-WinstFilePlanIntegrityFromCheck -FilePlan $FilePlan -Check $check
        $result = @{ Ok = $true }
        try { Complete-WinstPackageDownload -Download $dl -DestDir $downloadDir }
        catch { $result['CleanupError'] = ('文件已发布到 {0}，暂存清理失败：{1}' -f $commitTarget, $_.Exception.Message) }
        return $result
    } catch {
        return @{ Ok = $false; Error = ('下载 {0} 失败：{1}' -f $name, $_.Exception.Message); Network = $false }
    }
}
