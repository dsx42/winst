#Requires -Version 5.1

function Complete-WinstFileStage {
    <#
    .SYNOPSIS
        清理交付暂存，保留恢复标记保护的树；清理出错时保留最先发生的错误。
    #>
    param([Parameter(Mandatory = $true)][string]$StageDir,
        [Parameter(Mandatory = $true)][hashtable]$Delivery)

    if ($Delivery['PreserveStage']) {
        Invoke-WinstFileStep -Name '删暂存' -Skip ('待恢复，保留 ' + $StageDir)
        return $Delivery
    }
    try {
        Invoke-WinstFileStep -Name '删暂存' -Action {
            Remove-WinstDirectoryTree -Path $StageDir
        }
    } catch {
        $detail = '暂存清理失败（{0}）：{1}' -f $StageDir, $_.Exception.Message
        if ($Delivery.Ok) { $Delivery.Error = '文件已落位，' + $detail }
        else { $Delivery.Error += '；' + $detail }
        $Delivery.Ok = $false
    }
    return $Delivery
}
