#Requires -Version 5.1

function Get-WinstUpdateUnknownText {
    <#
    .SYNOPSIS
        「无法比较版本」的原因与将采取的动作文案。
    .OUTPUTS
        @{ Reason; Action }
    #>
    param($Snap)

    $reason = '软件源里没有可用的版本信息'
    $action = '按软件源里的定义更新'
    if ($Snap.VersionFromPackage) {
        # 版本号只能等主包取到才知道：更新时重新取包、再按包内版本决定是否更新
        $reason = '版本号取自主包文件信息'
        $action = '更新时重新取包核对版本'
    }
    return @{ Reason = $reason; Action = $action }
}
