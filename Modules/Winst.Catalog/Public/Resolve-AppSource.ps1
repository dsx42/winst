#Requires -Version 5.1

function Resolve-AppSource {
    <#
    .SYNOPSIS
        按 source.kind 分派到对应解析器；统一返回契约（Ok / Version / Tag / Repo / Files / Notes / Error）。
    .DESCRIPTION
        纯「读网络 + 计算」，不改动任何系统状态；异常在内部收敛为 Error，便于上层做失败隔离。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context,
        $Entry
    )

    $kind = ''
    try {
        $Entry = ConvertTo-WinstManifestEntry -Entry $Entry
        $kind = [string]$Entry['source']['kind']
        $null = Get-WinstPackageVersionSpec -Source $Entry['source']
    }
    catch {
        $failure = New-SourceResolveResult -Kind $kind
        $failure.Error = $_.Exception.Message
        return $failure
    }

    return (Resolve-WinstNormalizedAppSource -Context $Context -Entry $Entry)
}
