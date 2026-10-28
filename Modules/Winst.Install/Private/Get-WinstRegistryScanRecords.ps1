#Requires -Version 5.1

function Get-WinstRegistryScanRecords {
    <#
    .SYNOPSIS
        ③ 扫描注册表 Uninstall 键，把 installer 条目命中的记录写进 found。
    #>
    param([hashtable]$Context, $Plan, $Source, $Found, [switch]$Quiet, [switch]$VerboseOutput)

    # 先于目录登记执行：安装版软件可能装在 installRoot 之外，命中注册表即登记，installDir 取 InstallLocation。
    $registryEntries = @()
    try { $registryEntries = @(Get-WinstInstalledRegistryEntries) } catch { $registryEntries = @() }
    if ($registryEntries.Count -eq 0) { return }

    if (-not $Quiet) { Write-Host '  正在扫描系统安装记录（注册表）…' -ForegroundColor Gray }
    foreach ($id in @($Plan.Keys)) {
        if ($Found.Contains($id)) { continue }
        $app = $Plan[$id]
        $type = (Get-EntryString -Entry $app -Key 'type').Trim().ToLowerInvariant()
        if ($type -ne 'installer') { continue }

        # 名称规则：优先 detect.name；未声明时按条目 name 推导（安装版软件装在别处也照样识别）
        $detect = Get-EntryValue -Entry $app -Key 'detect' -Default $null
        $nameRule = Get-EntryString -Entry $detect -Key 'name'
        if (-not $nameRule) {
            $display = Get-EntryString -Entry $app -Key 'name'
            if (-not $display) { $display = $id }
            $nameRule = ('*' + (ConvertTo-WildcardLiteral -Text $display) + '*')
        }
        $rule = New-MatchRule -Rule $nameRule -Kind '软件名称'
        if (-not $rule.Ok) { continue }

        # 命中多个时优先取 InstallLocation 位于 installRoot 之下者
        $hit = $null
        $fallback = $null
        foreach ($entry in $registryEntries) {
            if (-not (Test-CompiledMatchRule -Rule $rule -Text ([string]$entry['DisplayName']))) { continue }
            if (-not $fallback) { $fallback = $entry }
            if (Test-WinstUnderInstallRoot -Path ([string]$entry['InstallLocation']) -InstallRoot $Context.InstallRoot) { $hit = $entry; break }
        }
        if (-not $hit) { $hit = $fallback }
        if (-not $hit) { continue }

        # 安装目录取记录里的实际值：InstallLocation 缺失时退回卸载程序 / 图标所在目录（见 Get-WinstRegistryEntryInstallDir）
        $location = Get-WinstRegistryEntryInstallDir -Entry $hit

        # 版本：**条目声明了 detect 就按它检测**（尊重清单配置）——如 .NET Desktop Runtime 的 jsonFile 读
        # runtimeconfig.json 得到 10.0.12，与源侧写法天然一致；未声明 detect 的 installer 在解析锁里是
        # 默认的 registry + 名称匹配，同样走这条路径。检测未命中才退回这条记录的 DisplayVersion，同样按
        # **检测侧**规则 detect.versionRewrite 归一。
        $version = ''
        $detectResult = Get-WinstDetectedVersion -Context $Context -Plan $app -InstallDir $location
        if ($detectResult.Ok -and $detectResult.Version) { $version = [string]$detectResult.Version }
        if (-not $version) {
            $kind = (Get-EntryString -Entry $detect -Key 'versionKind').Trim()
            $between = @(Get-EntryArray -Entry $detect -Key 'versionBetween')
            $version = Get-WinstVersionFromText -Text ([string]$hit['DisplayVersion']) -Kind $kind -Between $between
            $rewriteRules = @(Get-EntryArray -Entry $detect -Key 'versionRewrite')
            if ($version -and $rewriteRules.Count -gt 0) {
                $rewritten = Get-WinstRewrittenVersion -Version $version -Rules $rewriteRules
                if ($rewritten) { $version = $rewritten }
            }
        }
        if (-not $version) { $version = 'unknown' }
        $managed = 'external'
        if (Test-WinstUnderInstallRoot -Path $location -InstallRoot $Context.InstallRoot) { $managed = 'winst' }
        $Found[$id] = New-WinstScanRecord -Id $id -Version $version -OldVersions @($detectResult.OldVersions) -Type $type `
            -InstallDir $location -Managed $managed -Source ([string]$Source[$id])
        if ($VerboseOutput) {
            Write-Host ('    [注册表] {0} → 版本 {1}（{2}，{3}）' -f $id, $version, [string]$hit['DisplayName'], $managed) -ForegroundColor DarkGray
        }
    }
}
