#Requires -Version 5.1

function Complete-WinstPackageDownload {
    param([hashtable]$Download, [string]$DestDir)

    # 正式缓存已发布，先解除本地绑定，再清理本次工作目录。
    $path = $Download['RecordPath']
    try {
        if ($path) { Remove-Item -LiteralPath $path -ErrorAction Stop }
        $path = $Download.WorkDir
        if ($path -ne $DestDir) { Clear-WinstInstallDir -Dir $path -AllowedRoot $DestDir -Strict }
    } catch { throw ('无法清理 {0}：{1}' -f $path, $_.Exception.Message) }
}
