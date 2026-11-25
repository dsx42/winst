#Requires -Version 5.1

function Invoke-WinstPackageDownload {
    <#
    .SYNOPSIS
        尝试下载一次。优先使用本机服务，服务未接单时可独立运行 CLI，缺少 CLI 时允许引导下载。
    #>
    param([hashtable]$Context, [string]$Url, [string]$DestDir, [string]$FileName,
        [hashtable]$Headers, [string]$ProxyUrl, [string]$Version, [string]$ExpectedHash,
        [switch]$Restart, [switch]$Bootstrap, [string]$SizeText = '大小未知', [switch]$Quiet)

    $uri = $null
    if (-not [Uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri) -or
        $uri.Scheme -notin @('http', 'https', 'ftp', 'magnet') -or -not (Test-WinstArgumentSafe -Value $Url)) {
        return @{ Ok = $false; FailureKind = 'Other'; Error = '下载地址不合法' }
    }
    if (-not (Test-WinstSafePathSegment -Name $FileName) -or $FileName -in @('.tasks', '.local')) {
        return @{ Ok = $false; FailureKind = 'Other'; Error = ('下载文件名无效或与暂存目录冲突：' + $FileName) }
    }
    if (-not $Headers) { $Headers = @{} }
    try {
        Assert-WinstSafeWritePath -Path $DestDir -Directory
        $failedDir = Join-Path (Join-Path (Join-Path $DestDir '.local') $FileName) 'failed'
        Clear-WinstInstallDir -Dir $failedDir -AllowedRoot $DestDir -Strict
        $service = Invoke-WinstFluxServiceDownload -Url $Url -DestDir $DestDir -FileName $FileName `
            -Headers $Headers -ProxyUrl $ProxyUrl -Version $Version -ExpectedHash $ExpectedHash -Restart:$Restart `
            -Config $Context.Config -SizeText $SizeText -Quiet:$Quiet
        if (-not $service['FallbackReason']) { return $service }

        $exe = Get-WinstEngineExe -Context $Context -Id (Get-WinstDownloadEngineId)
        if (-not $exe -and -not $Bootstrap) {
            return @{ Ok = $false; FailureKind = 'MissingEngine'; Error = '缺少 FluxDown CLI' }
        }
        if (-not $exe -and $uri.Scheme -eq 'magnet') {
            throw 'HTTP 引导下载仅支持 HTTP、HTTPS 和 FTP 地址。下载 magnet 地址需要可用的 FluxDown 服务或 CLI。'
        }
        $workDir = Join-WinstPath $DestDir ([guid]::NewGuid().ToString('N'))
        Assert-WinstSafeWritePath -Path $workDir -Directory
        $null = New-Item -ItemType Directory -Path $workDir -ErrorAction Stop
        if ($exe) {
            $mode = 'FluxDown 独立 CLI（{0}）' -f $service.FallbackReason
            Write-WinstDownloadStart $FileName $SizeText $mode -Quiet:$Quiet
            $result = Invoke-WinstFluxDownDownload -Exe $exe -Url $Url -WorkDir $workDir -FileName $FileName -Headers $Headers -ProxyUrl $ProxyUrl
        } else {
            Write-WinstDownloadStart $FileName $SizeText 'HTTP 引导下载' -Quiet:$Quiet
            $target = Join-WinstPath $workDir $FileName
            $result = Save-WinstFileWithHttp -Uri $Url -OutFile $target -Headers $Headers -ProxyUrl $ProxyUrl
            $result.WorkDir = $workDir
            if ($result.Ok) { $result.Path = $target }
        }
        if ($result['WorkDir']) {
            $result.FailedDir = $failedDir
            if (-not $result.Ok) {
                $retained = Reject-WinstPackageDownload $result
                $result.Error = '{0}，暂存位置 {1}' -f $result.Error, $retained
            }
        }
        return $result
    } catch {
        return @{ Ok = $false; FailureKind = 'Other'; Error = $_.Exception.Message }
    }
}
