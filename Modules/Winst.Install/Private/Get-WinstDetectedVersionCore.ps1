#Requires -Version 5.1

function Get-WinstDetectedVersionCore {
    <#
    .SYNOPSIS
        按 detect.method 检测版本，按清单规则改写版本号并选出最新版本。
    .DESCRIPTION
        registry / fileVersion / markerFile / jsonFile 会累积检测到的版本，并将其余版本记入旧版本列表。
        appx 选择一个匹配的软件包并读取其版本。cliVersion 从命令输出中识别版本。
    .OUTPUTS
        @{ Ok; Found; Version; Versions; OldVersions; Method; Detail; Note; QuerySucceeded }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Plan,
        [string]$InstallDir,
        $RegistryMatches = $null
    )

    # Detail = 检测途径（命令 / 文件 / 记录，供详情展示）；Note = 需要提醒用户的异常原因（超时、缺 java 等，
    # 安装流程会以一行「提示」给出；正常未命中时为空，不打扰用户）
    $result = @{
        Ok          = $false
        Found       = $false
        Version     = ''
        Versions    = New-Object 'System.Collections.Generic.List[object]'
        OldVersions = @()
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
            Get-WinstVersionFromRegistry -Plan $Plan -InstallDir $InstallDir -Result $result -RegistryMatches $RegistryMatches
        }
        'fileVersion' {
            Get-WinstVersionFromFileVersion -Context $Context -Detect $detect -InstallDir $InstallDir `
                -Kind $kind -Between $between -Result $result
        }
        'markerFile' {
            Get-WinstVersionFromMarkerFile -Context $Context -Detect $detect -InstallDir $InstallDir `
                -Kind $kind -Between $between -Result $result
        }
        'jsonFile' {
            Get-WinstVersionFromJsonFile -Context $Context -Detect $detect -InstallDir $InstallDir `
                -Kind $kind -Between $between -Result $result
        }
        'appx' {
            Get-WinstVersionFromAppx -Detect $detect `
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
    $rewriteRules = @()
    if ($method -ne 'registry') { $rewriteRules = @(Get-EntryArray -Entry $detect -Key 'versionRewrite') }
    Complete-WinstDetectedVersion -Result $result -RewriteRules $rewriteRules

    # 旧版本缺移除入口时（文件类检测只知道「还有这个版本的文件」），按版本号反查系统安装记录把它补上；
    # 已有入口但那条记录现在卸不了（外层引导包的卸载器被磁盘清理删掉）时，换成同版本里可用的那条
    if (@($result.OldVersions).Count -gt 0) {
        $patched = New-Object 'System.Collections.Generic.List[object]'
        $productEntries = $null
        foreach ($item in @($result.OldVersions)) {
            $version = [string]$item['Version']
            $recordKey = [string]$item['RecordKey']
            $keep = $false
            if ($recordKey) {
                try { $props = Read-WinstUninstallRegistryEntry -KeyPath $recordKey } catch {
                    $result.Ok = $false
                    $result.QuerySucceeded = $false
                    $result.Note = ('读取旧版本卸载记录失败：{0}' -f $_.Exception.Message)
                    return $result
                }
                if ($props) {
                    # 卸载键里的属性都是可选的：StrictMode 2 下直接取 $props.UninstallString
                    # 会抛 PropertyNotFoundException，把整个版本检测（进而是安装 / 更新 / 修复）打断
                    $keep = Test-WinstUninstallerUsable -Entry $props
                }
            }
            if (-not $keep) {
                if ($null -eq $productEntries) { $productEntries = @(Get-WinstRegistryEntriesForPlan -Plan $Plan) }
                $fallback = Resolve-WinstOldVersionRecordKey -Plan $Plan -Version $version -Entries $productEntries
                if ($fallback) { $recordKey = $fallback }
            }
            $patched.Add([ordered]@{
                Version   = $version
                Detail    = [string]$item['Detail']
                RecordKey = $recordKey
            })
        }
        $result['OldVersions'] = $patched.ToArray()
    }
    return $result
}
