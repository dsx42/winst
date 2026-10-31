#Requires -Version 5.1

function Get-WinstDetectedVersionCore {
    <#
    .SYNOPSIS
        版本检测的实际实现（未做 versionRewrite 归一，见上面的 Get-WinstDetectedVersion）。
    .DESCRIPTION
        只做分派：每种 detect.method 一个函数（registry / fileVersion / markerFile / jsonFile / appx / cliVersion），
        各检测方式把命中的版本写进传入的结果对象；未命中时保持 Ok = $false。
        能命中多个版本的检测方式（registry / fileVersion / markerFile / jsonFile / appx）累积到
        `Result.Versions`，再由 Complete-WinstDetectedVersion 挑出最新版本、其余记为旧版本。
    .OUTPUTS
        @{ Ok; Found; Version; Versions; OldVersions; Method; Detail; Note; QuerySucceeded }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Plan,
        [string]$InstallDir = ''
    )

    # Detail = 检测途径（命令 / 文件 / 记录，供详情展示）；Note = 需要提醒用户的异常原因（超时、缺 java 等，
    # 安装流程会以一行「提示」给出；正常未命中时为空，不打扰用户）
    $result = @{
        Ok          = $false
        Found       = $false
        Version     = ''
        Versions    = @()
        OldVersions = @()
        Method      = 'none'
        Detail      = ''
        Note        = ''
        QuerySucceeded = $false
    }

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

    # 系统记录只在完整查询成功时可信，部分命中不能掩盖权限或枚举失败。
    if (@('registry', 'appx') -contains $method -and -not [bool]$result.QuerySucceeded) { $result.Ok = $false; return $result }

    # 归一写法 + 挑出最新版本（单值检测方式只有一条，等于原样沿用）
    Complete-WinstDetectedVersion -Result $result -RewriteRules @(Get-EntryArray -Entry $detect -Key 'versionRewrite')

    # 旧版本缺移除入口时（文件类检测只知道「还有这个版本的文件」），按版本号反查系统安装记录把它补上；
    # 已有入口但那条记录现在卸不了（外层引导包的卸载器被磁盘清理删掉）时，换成同版本里可用的那条
    if (@($result.OldVersions).Count -gt 0) {
        $patched = @()
        foreach ($item in @($result.OldVersions)) {
            $version = [string]$item['Version']
            $recordKey = [string]$item['RecordKey']
            $keep = $false
            if ($recordKey) {
                $props = $null
                try { $props = Get-ItemProperty -LiteralPath $recordKey -ErrorAction SilentlyContinue } catch { $props = $null }
                if ($props) {
                    # 卸载键里的属性都是可选的：StrictMode 2 下直接取 $props.UninstallString
                    # 会抛 PropertyNotFoundException，把整个版本检测（进而是安装 / 更新 / 修复）打断
                    $keep = Test-WinstUninstallerUsable -Entry ([ordered]@{
                            UninstallString = (Get-EntryString -Entry $props -Key 'UninstallString')
                        })
                }
            }
            if (-not $keep) {
                $fallback = Resolve-WinstOldVersionRecordKey -Plan $Plan -Version $version
                if ($fallback) { $recordKey = $fallback }
            }
            $patched += [ordered]@{
                Version   = $version
                Detail    = [string]$item['Detail']
                RecordKey = $recordKey
            }
        }
        $result['OldVersions'] = @($patched)
    }
    return $result
}
