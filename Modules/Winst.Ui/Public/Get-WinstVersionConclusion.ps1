#Requires -Version 5.1

function Get-WinstVersionConclusion {
    <#
    .SYNOPSIS
        生成「已装软件能否升级」或「安装包能否更新」的一句结论（含显示颜色），供列表 / 详情 / 命令行共用。
    .DESCRIPTION
        Kind = installed：「已安装的版本 vs 默认更新来源的版本」的结论；
        Kind = package  ：「已下载包里的版本 vs 软件源里最高可用版本」的结论。
        两句结论的措辞与颜色集中在这里定义一次，避免列表、详情页与 CLI 三处各写一套。
    .OUTPUTS
        @{ Text; Color }
    #>
    param(
        [Parameter(Mandatory = $true)]$Item,
        [ValidateSet('installed', 'package')][string]$Kind
    )

    if ($Kind -eq 'installed') {
        $latestText = [string]$Item['LatestVersion']
        switch ([string]$Item['InstalledUpdateState']) {
            'update'  { return @{ Text = [string]$Item['InstalledUpdateHint']; Color = 'Green' } }
            'latest'  { return @{ Text = ('已是最新（默认更新来源 {0}）' -f $latestText); Color = 'Gray' } }
            'newer'   { return @{ Text = ('默认更新来源为 {0}，比本机旧' -f $latestText); Color = 'DarkYellow' } }
            'unknown' {
                if ([string]$Item['InstalledUpdateHint']) { return @{ Text = [string]$Item['InstalledUpdateHint']; Color = 'DarkYellow' } }
                return @{ Text = '软件源里没有可用的版本信息'; Color = 'DarkYellow' }
            }
            default { return @{ Text = '软件源里没有这个软件'; Color = 'DarkYellow' } }
        }
    }

    $bestText = '未知'
    if ([string]$Item['BestVersion']) { $bestText = [string]$Item['BestVersion'] }
    switch ([string]$Item['PackageUpdateState']) {
        'update'        { return @{ Text = [string]$Item['PackageUpdateHint']; Color = 'Green' } }
        'latest'        { return @{ Text = ('已是最新（软件源里最高 {0}）' -f $bestText); Color = 'Gray' } }
        'newer'         { return @{ Text = ('软件源里最高 {0}，比下载包里的旧' -f $bestText); Color = 'DarkYellow' } }
        'cache-unknown' {
            # 「仅下载」类型的软件没有安装这一步，只说「下载时会自动核对」
            $whenText = '安装'
            if ([string]$Item['Type'] -eq 'download') { $whenText = '下载' }
            return @{ Text = ('版本未知（索引里没有记录，{0}时会自动核对）' -f $whenText); Color = 'DarkYellow' }
        }
        'unknown'       {
            if ([string]$Item['PackageUpdateHint']) { return @{ Text = [string]$Item['PackageUpdateHint']; Color = 'DarkYellow' } }
            return @{ Text = '软件源里没有可用的版本信息'; Color = 'DarkYellow' }
        }
        default         { return @{ Text = '软件源里没有这个软件'; Color = 'DarkYellow' } }
    }
}
