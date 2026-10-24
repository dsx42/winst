#Requires -Version 5.1

function Resolve-WinstUninstallMethod {
    <#
    .SYNOPSIS
        ③ 卸载方式判定（冲突时以安装记录为准）与「依据」说明。
    .OUTPUTS
        @{ Method; Notes; Sources }
    #>
    param([switch]$IsSelf, [switch]$External, $RecordSnapshot, $ManifestSnapshot, [switch]$HasManifest)

    $notes = @()
    $method = 'portable-dir'
    if ($IsSelf) {
        $method = 'portable-dir'
    } elseif ($External) {
        # 仅登记的条目：软件源里定义了卸载方式就按它卸载；两处都没有定义才退回
        # 「只移除安装记录」——不删用户自己安装的程序文件
        if ([string]$RecordSnapshot['method']) {
            $method = [string]$RecordSnapshot['method']
        } elseif ($HasManifest -and [string]$ManifestSnapshot['method']) {
            $method = [string]$ManifestSnapshot['method']
            $notes += '该软件不是 winst 安装的，按软件源里定义的卸载方式执行'
        } else {
            $method = 'record-only'
        }
    } elseif ([string]$RecordSnapshot['method']) {
        $method = [string]$RecordSnapshot['method']
        if ($HasManifest -and [string]$ManifestSnapshot['method'] -and ([string]$ManifestSnapshot['method'] -ne $method)) {
            $notes += ('软件源里的卸载方式（{0}）与安装时的记录（{1}）不同，已按安装时的记录执行' -f [string]$ManifestSnapshot['method'], $method)
        }
    } elseif ($HasManifest -and [string]$ManifestSnapshot['method']) {
        $method = [string]$ManifestSnapshot['method']
    } else {
        # 两处都没有卸载定义：
        # 回退为「删除安装目录 + 移除安装记录」
        $method = 'portable-dir'
    }

    # 卸载方式只认白名单：未知值（拼错的 `exe` / `msi`）不能落进 Invoke-WinstRemovePayload 的
    # default 分支、递归删除整个安装目录；对「仅登记」的外部条目更会删掉用户自己安装的程序文件
    $allowed = @('portable-dir', 'registry', 'appx', 'clean-cache', 'record-only')
    if ($allowed -notcontains $method) {
        $notes += ('卸载方式「{0}」无法识别，已按「只移除安装记录」处理（不动程序文件）' -f $method)
        $method = 'record-only'
    }

    $sources = @()
    $hasRecord = -not (Test-WinstUninstallSnapshotEmpty -Snapshot $RecordSnapshot)
    if ($hasRecord) { $sources += '安装记录（安装时保存）' }
    if ($HasManifest) { $sources += '软件源（当前定义）' }
    if ($sources.Count -eq 0) { $sources += '没有卸载定义，按默认方式处理（删除安装目录 + 移除安装记录）' }

    return @{ Method = $method; Notes = @($notes); Sources = @($sources) }
}
