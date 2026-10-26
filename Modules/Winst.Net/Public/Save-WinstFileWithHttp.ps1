#Requires -Version 5.1

function Save-WinstFileWithHttp {
    <#
    .SYNOPSIS
        用 Invoke-WebRequest 下载文件（软件包 / 引擎包 / winst 自身更新包）。
    .DESCRIPTION
        属于「下载类」请求：`proxyMode = download-direct` 时先直连、失败再走代理。
    .OUTPUTS
        @{ Ok; Error }
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][string]$OutFile,
        [int]$TimeoutSec = 900
    )

    $result = @{ Ok = $false; Error = '' }
    $dir = Split-Path -Parent $OutFile
    if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $dir -Force -ErrorAction SilentlyContinue
    }

    $attempts = @(Get-WinstProxyAttempts -Context $Context -Download)
    $lastError = ''
    foreach ($currentProxy in $attempts) {
        $tempPath = '{0}.part-{1}' -f $OutFile, ([Guid]::NewGuid().ToString('N').Substring(0, 6))
        try {
            $params = @{ Uri = $Uri; OutFile = $tempPath; UseBasicParsing = $true; TimeoutSec = $TimeoutSec }
            if ($currentProxy) { $params['Proxy'] = $currentProxy }
            $null = Invoke-WebRequest @params
            if (Test-Path -LiteralPath $tempPath -PathType Leaf) {
                Move-Item -LiteralPath $tempPath -Destination $OutFile -Force
                $result.Ok = $true
                return $result
            }
            $lastError = '下载完成后没有生成文件'
        } catch {
            $lastError = $_.Exception.Message
        } finally {
            if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue }
        }
    }
    $result.Error = $lastError
    return $result
}
