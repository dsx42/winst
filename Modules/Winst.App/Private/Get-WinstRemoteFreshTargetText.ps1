#Requires -Version 5.1

function Get-WinstRemoteFreshTargetText {
    <#
    .SYNOPSIS
        把「远端新鲜度」结论转成展示用的目标版本文案（更新列表 / 下载列表 / 检查更新共用）。
    .DESCRIPTION
        versionFromPackage 条目在解析阶段做过一次 HEAD 比对，结论存在解析锁的 remoteFresh 字段：
          changed   → 远端有新包，版本要取包后才知道
          unchanged → 远端无新包，缓存里那份就是软件源当前这份，目标版本直接用它
          unknown   → HEAD 没比出结论，如实说明
        三档文案由这一个函数生成，调用方（Invoke-WinstUpgradeAll / Invoke-WinstDownloadUpdates 的列表与执行标题 /
        Write-WinstUpdateCheckList）只传括号里的解释（-UnchangedSuffix）。
    .OUTPUTS
        [string] 目标版本文案
    #>
    param(
        $Row,
        # 调用方已算好的版本（可能为空）
        [string]$FallbackVersion = '',
        # unchanged 且已知版本时，括号里追加的解释（两处措辞不同，必须传入）
        [string]$UnchangedSuffix = ''
    )

    $fresh = Get-WinstRowRemoteFreshState -Row $Row
    if ($fresh -ieq 'changed') { return '远端有新包（HEAD 检测），取包后确认版本' }
    if ($fresh -ieq 'unchanged') {
        if ($FallbackVersion) {
            $note = '远端无新包'
            if ($UnchangedSuffix) { $note += '，' + $UnchangedSuffix }
            return ('{0}（{1}）' -f $FallbackVersion, $note)
        }
        return '远端无新包（缓存里那份版本未知），取包后确认版本'
    }
    return '取包后确认版本（HEAD 检测未得出结论）'
}
