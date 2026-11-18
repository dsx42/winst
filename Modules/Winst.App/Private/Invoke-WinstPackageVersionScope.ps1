#Requires -Version 5.1

function Invoke-WinstPackageVersionScope {
    <#
    .SYNOPSIS
        同一批安装最多保留一个已取版包的只读句柄，退出、取消及失败时统一释放。
    #>
    param([hashtable]$Context, [scriptblock]$Action)

    if ($Context.ContainsKey('PackageVersionLease')) { return (& $Action) }
    $Context['PackageVersionLease'] = @{}
    try { & $Action }
    finally {
        $lease = $Context['PackageVersionLease']
        if ($lease -and $lease['Stream']) { $lease['Stream'].Dispose() }
        $Context.Remove('PackageVersionLease')
    }
}
