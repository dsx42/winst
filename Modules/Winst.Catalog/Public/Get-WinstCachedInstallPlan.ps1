#Requires -Version 5.1

function Get-WinstCachedInstallPlan {
    <#
    .SYNOPSIS
        已知主包与解析锁版本不同时，取同来源清单定义，用缓存版本展开完整的执行步骤。
    #>
    param([hashtable]$Context, $Plan, [string]$CachedVersion)

    $version = Get-EntryString -Entry $Plan -Key 'version'
    if ($version -ceq $CachedVersion) { return $Plan }
    # 未知版本下能成功生成的执行步骤不含版本占位符。
    if (-not $version) {
        $copy = Copy-WinstObjectShallow -InputObject $Plan
        $copy['version'] = $CachedVersion
        return $copy
    }

    $id = Get-EntryString -Entry $Plan -Key 'id'
    $origin = Get-EntryString -Entry $Plan -Key 'manifestOrigin'
    $type = Get-EntryString -Entry $Plan -Key 'type'
    $definition = $null
    $defaults = @{}
    $source = @(Get-ManifestSourceList -Context $Context | Where-Object { $_['name'] -ceq $origin })
    if ($source.Count) {
        $body = Get-WinstSourceEntries -Context $Context -Source $source[0]
        foreach ($entry in $body.Entries) {
            if ((Get-EntryString -Entry $entry -Key 'id') -cne $id) { continue }
            $raw = ConvertTo-WinstManifestEntry -Entry $entry
            if ((ConvertTo-WinstEntryType -Type $raw.type) -ne $type -or
                    -not (Test-WinstJsonValueEqual -Left @(Get-EntryArray -Entry $raw -Key 'dependencies') -Right @(Get-EntryArray -Entry $Plan -Key 'dependencies'))) { break }
            $pinned = Get-EntryString -Entry $raw -Key 'version'
            if ($pinned) {
                $rules = New-WinstVersionRewriteRules -Spec (Get-EntryValue -Entry $raw.source -Key 'versionRewrite')
                if (-not $rules.Ok) { break }
                $pinned = Get-WinstRewrittenVersion -Version $pinned -Rules $rules.Rules
            }
            if (-not $pinned -or $pinned -ceq $CachedVersion) { $definition = $raw }
            else {
                $inner = Get-EntryString -Entry $raw -Key 'installerExe'
                if ($inner -and (Expand-VersionPlaceholder -Text $inner -Version $CachedVersion) -cne (Expand-VersionPlaceholder -Text $inner -Version $version)) {
                    $defaults['installerExe'] = $inner
                    $defaults['stripTopDir'] = Get-EntryValue -Entry $raw -Key 'stripTopDir'
                }
            }
            break
        }
    }

    # 只有解析锁或正文只声明了其它固定版本时，核对其执行步骤是否就是主包的默认安装方式。
    if (-not $definition -and $type -in @('file', 'installer')) {
        $probe = Copy-WinstObjectShallow -InputObject $Plan
        $probe['processes'] = @()
        $savedNotes = $probe['notes']
        $probe = Complete-WinstInstallPlan -Plan $probe -Entry $defaults -Version $version -Notes @()
        $probe['notes'] = $savedNotes
        if (Test-WinstJsonValueEqual -Left $probe -Right $Plan) { $definition = $defaults }
    }
    if ($null -ne $definition) {
        $copy = Copy-WinstObjectShallow -InputObject $Plan
        $copy['version'] = $CachedVersion
        $copy['processes'] = @(Get-EntryArray -Entry $definition -Key 'processes')
        $copy['ok'] = $false
        $candidate = Complete-WinstInstallPlan -Plan $copy -Entry $definition -Version $CachedVersion -Notes @()
        if ($candidate.ok) { return $candidate }
    }
    throw ('无法安装 {0}：主包缓存版本为 {1}，解析锁版本为 {2}，没有匹配缓存版本的完整安装计划。' -f $id, $CachedVersion, $version)
}
