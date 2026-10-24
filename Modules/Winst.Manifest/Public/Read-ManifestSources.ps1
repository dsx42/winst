#Requires -Version 5.1

function Read-ManifestSources {
    <#
    .SYNOPSIS
        读取共享的软件源列表；文件缺失 / 损坏 / 为空时返回空数组。
    .OUTPUTS
        @( @{ name; repo; url } )：name = repo = 「用户名/仓库」
    #>
    param([Parameter(Mandatory = $true)][string]$PkgDir)

    $path = Get-ManifestSourcesPath -PkgDir $PkgDir
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }

    $result = New-Object 'System.Collections.Generic.List[object]'
    try {
        $raw = Get-Content -LiteralPath $path -Raw -Encoding UTF8
        if (-not $raw -or -not $raw.Trim()) { return @() }
        $obj = $raw | ConvertFrom-Json
        $list = Get-EntryValue -Entry $obj -Key 'sources' -Default $null
        if ($null -eq $list) { $list = $obj }
        foreach ($entry in @($list)) {
            $repo = Get-EntryString -Entry $entry -Key 'repo'
            if (-not $repo) { $repo = Get-EntryString -Entry $entry -Key 'name' }
            if (-not $repo) { continue }
            $result.Add([ordered]@{
                name = $repo
                repo = $repo
                url  = (Get-EntryString -Entry $entry -Key 'url')
            })
        }
    } catch {
        return @()
    }
    return @($result.ToArray())
}
