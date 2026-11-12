#Requires -Version 5.1

function Read-ManifestSources {
    <#
    .SYNOPSIS
        读取共享的软件源列表；仅文件缺失返回空数组，读取或格式错误时停止。
    .OUTPUTS
        @( @{ name; repo; url } )：name = repo = 「用户名/仓库」
    #>
    param([Parameter(Mandatory = $true)][string]$PkgDir, [switch]$PreserveOfficialEntries)

    $path = Get-ManifestSourcesPath -PkgDir $PkgDir
    try { $null = Get-Item -LiteralPath $path -Force -ErrorAction Stop }
    catch {
        if ($_.Exception -is [System.Management.Automation.ItemNotFoundException]) { return @() }
        throw
    }

    $result = New-Object 'System.Collections.Generic.List[object]'
    try {
        $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8 -ErrorAction Stop
        if (-not $raw -or -not $raw.Trim()) { throw '文件内容为空' }
        $obj = ConvertFrom-Json -InputObject $raw -ErrorAction Stop
        $list = $obj
        if ($obj -isnot [System.Array]) {
            $prop = $obj.PSObject.Properties['sources']
            if (-not $prop -or $prop.Value -isnot [System.Array]) { throw '源列表必须是数组或含 sources 数组的对象' }
            $list = $prop.Value
        }
        $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
        $officialSeen = $false
        foreach ($entry in @($list)) {
            if ($entry -isnot [System.Management.Automation.PSCustomObject]) { throw '源列表条目必须是对象' }
            $repo = Get-EntryString -Entry $entry -Key 'repo'
            if (-not $repo) { $repo = Get-EntryString -Entry $entry -Key 'name' }
            if (-not $repo) { throw '源列表条目缺少 repo / name' }
            $name = Get-EntryString -Entry $entry -Key 'name'
            if (-not $name) { $name = $repo }
            if ($repo -ieq (Get-WinstOfficialManifestName) -or $name -ieq (Get-WinstOfficialManifestName)) {
                $officialSeen = $true
                if ($PreserveOfficialEntries) { $result.Add([ordered]@{ name = $name; repo = $repo; url = (Get-EntryString -Entry $entry -Key 'url') }) }
                continue
            }
            $parsed = Resolve-GitHubManifestInput -RepoOrUrl $repo
            if (-not $parsed.Ok -or $parsed.Repo -cne $repo) { throw ('软件源 repo 必须是有效的 owner/repo：' + $repo) }
            if (-not $seen.Add($repo)) { throw ('软件源名称重复：' + $repo) }
            $result.Add([ordered]@{
                name = $repo
                repo = $repo
                url  = (Get-EntryString -Entry $entry -Key 'url')
            })
        }
        if ($officialSeen -and -not $PreserveOfficialEntries) {
            $result.Insert(0, [ordered]@{ name = (Get-WinstOfficialManifestName); repo = (Get-WinstOfficialManifestName); url = (Get-WinstOfficialManifestUrl) })
        }
    } catch {
        throw ('读取软件源列表失败（已保留原文件 {0}）：{1}' -f $path, $_.Exception.Message)
    }
    return @($result.ToArray())
}
