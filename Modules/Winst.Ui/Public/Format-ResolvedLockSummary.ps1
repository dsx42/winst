#Requires -Version 5.1

function Format-ResolvedLockSummary {
    <#
    .SYNOPSIS
        把软件清单概况格式化为一行文本（软件数 / 可用 / 有误 / 读取时间）。
    #>
    param($Meta)

    if (-not $Meta -or -not $Meta.HasApps) { return '还没读取过（请先刷新软件源）' }

    $apps = @($Meta.Apps)
    $okCount = 0
    foreach ($app in $apps) {
        if (Get-EntryBool -Entry $app -Key 'ok') { $okCount++ }
    }

    $text = ('{0} 个软件（可用 {1} / 有误 {2}）' -f $apps.Count, $okCount, ($apps.Count - $okCount))
    if ($Meta.ResolvedAt) { $text += '  读取于 ' + (Format-ManifestTime -Value $Meta.ResolvedAt) }
    return $text
}
