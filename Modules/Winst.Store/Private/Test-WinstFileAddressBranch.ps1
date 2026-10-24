#Requires -Version 5.1

function Test-WinstFileAddressBranch {
    <#
    .SYNOPSIS
        ② 地址变了 = 缓存里放的是另一份文件（文件名固定而地址变化时，如 direct 源的固定地址包）。
    .OUTPUTS
        [bool] 是否命中该分支
    #>
    param($Plan, $Meta, [string]$Url)

    if (-not $Meta.Exists -or -not $Meta.Url -or ($Meta.Url -ieq $Url)) { return $false }
    # 显式写 NeedDownload，不依赖 New-WinstFilePlanEntry 的默认 $true：
    # 上游一旦插入把 NeedDownload 置假的判定，就会出现「提示要重新下载、实际沿用旧缓存」。
    $Plan['NeedDownload'] = $true
    # 仅下载类型的签名链接已由版本优先判定兜住，走不到这里
    $Plan['Reason'] = '文件地址已变化（缓存记录的是另一份），将重新下载'
    return $true
}
