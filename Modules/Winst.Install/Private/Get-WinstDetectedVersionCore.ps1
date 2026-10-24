#Requires -Version 5.1

function Get-WinstDetectedVersionCore {
    <#
    .SYNOPSIS
        版本检测的实际实现（未做 versionRewrite 归一，见上面的 Get-WinstDetectedVersion）。
    .DESCRIPTION
        只做分派：每种 detect.method 一个函数（registry / fileVersion / markerFile / jsonFile / appx / cliVersion），
        各检测方式只往传入的结果对象里写，未命中时保持 Ok = $false（与拆分前逐分支 return 语义一致）。
    .OUTPUTS
        @{ Ok; Found; Version; Method; Detail; Note }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Plan,
        [string]$InstallDir = '',
        [string]$SourceName = '',
        [string]$PkgDirForCli = ''
    )

    # Detail = 检测途径（命令 / 文件 / 记录，供详情展示）；Note = 需要提醒用户的异常原因（超时、缺 java 等，
    # 安装流程会以一行「提示」给出；正常未命中时为空，不打扰用户）
    $result = @{ Ok = $false; Found = $false; Version = ''; Method = 'none'; Detail = ''; Note = '' }

    $detect = Get-EntryValue -Entry $Plan -Key 'detect' -Default $null
    $method = (Get-EntryString -Entry $detect -Key 'method').Trim().ToLowerInvariant()
    if (-not $method) { $method = 'none' }
    $result.Method = $method
    if ($method -eq 'none') { return $result }

    $kind = (Get-EntryString -Entry $detect -Key 'versionKind').Trim()
    $between = @(Get-EntryArray -Entry $detect -Key 'versionBetween')

    switch ($method) {
        'registry' {
            Get-WinstVersionFromRegistry -Context $Context -Plan $Plan -Detect $detect -InstallDir $InstallDir `
                -Kind $kind -Between $between -Result $result
        }
        'fileVersion' {
            Get-WinstVersionFromFileVersion -Context $Context -Plan $Plan -Detect $detect -InstallDir $InstallDir `
                -Kind $kind -Between $between -Result $result
        }
        'markerFile' {
            Get-WinstVersionFromMarkerFile -Context $Context -Plan $Plan -Detect $detect -InstallDir $InstallDir `
                -Kind $kind -Between $between -Result $result
        }
        'jsonFile' {
            Get-WinstVersionFromJsonFile -Context $Context -Plan $Plan -Detect $detect -InstallDir $InstallDir `
                -Kind $kind -Between $between -Result $result
        }
        'appx' {
            Get-WinstVersionFromAppx -Context $Context -Plan $Plan -Detect $detect -InstallDir $InstallDir `
                -Kind $kind -Between $between -Result $result
        }
        'cliVersion' {
            Get-WinstVersionFromCli -Context $Context -Plan $Plan -Detect $detect -InstallDir $InstallDir `
                -Kind $kind -Between $between -Result $result
        }
    }
    return $result
}
