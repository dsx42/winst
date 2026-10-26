#Requires -Version 5.1

function Resolve-WinstOldVersionRecordKey {
    <#
    .SYNOPSIS
        给不带移除入口的旧版本，按系统安装记录里的显示名反查它的卸载键路径。
    .DESCRIPTION
        文件类检测（jsonFile / markerFile / fileVersion）只知道「本机还有 x.y.z 这个版本的文件」，
        不知道它对应哪条系统安装记录。升级后旧版本没被清掉的软件（.NET 运行时这类）通常在
        卸载记录里留着显示名带版本号的记录，按版本号反查就能拿到它的卸载入口。

        同一个版本常有两层记录（外层 burn 引导包 + 内层 MSI），而外层那个的卸载器文件
        可能已经被磁盘清理删掉（记录却还在）。因此这里按**现在是否可用**挑：
        可用的外层引导包 → 可用的 MSI → 不可用的外层 → 不可用的 MSI。

        一条记录都没有时保持为空，调用方如实告诉用户去「设置 → 应用」里手动卸载，不做猜测。
    .OUTPUTS
        [string] 卸载键路径；查不到返回空串
    #>
    param($Plan, [string]$Version)

    $candidates = @(Resolve-WinstOldVersionCandidateKeys -Plan $Plan -Version $Version)
    if ($candidates.Count -eq 0) { return '' }
    return [string]$candidates[0]
}
