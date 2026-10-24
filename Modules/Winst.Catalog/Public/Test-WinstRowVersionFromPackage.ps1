#Requires -Version 5.1

function Test-WinstRowVersionFromPackage {
    <#
    .SYNOPSIS
        这一行的版本号是否「只能等主包取到才知道」。
    .DESCRIPTION
        这类条目的版本号取自（或将要取自主包文件的 FileVersion）——软件源里既没有版本号、也没有任何能判断
        「缓存里那份是不是当前这一份」的信息，所以**缓存里那份包的版本不能当判据**：安装 / 更新 / 下载都
        必须重新取包。有一个可用来源写出了版本号（清单维护者给了版本）时返回假——那时按
        正常的版本比较走。
    .OUTPUTS
        [bool]
    #>
    param($Row)

    if (-not $Row) { return $false }
    $usable = 0
    foreach ($entry in @($Row['Sources'])) {
        if (-not $entry['Ok']) { continue }
        $usable++
        if (-not (Get-EntryBool -Entry $entry['Plan'] -Key 'versionFromPackage')) { return $false }
    }
    return [bool]($usable -gt 0)
}
