#Requires -Version 5.1

function Add-WinstVersionItem {
    <#
    .SYNOPSIS
        把一次「命中的版本」记进检测结果（各 detect.method 共用）。
    .DESCRIPTION
        同一个软件可能同时存在多个版本（如 .NET 运行时的
        `shared\Microsoft.WindowsDesktop.App\10.0.12` 与 `10.0.14`）：把这些实例逐个记下来，
        由 Complete-WinstDetectedVersion 统一挑出最新版本、其余作为旧版本返回。

        两个附加字段决定「哪些算同一个软件的旧版本」与「怎么卸掉它」：

        - `GroupKey`：同一个产品的标识。文件类检测用文件所在目录，注册表检测用「抹掉版本号的
          DisplayName」。只有 GroupKey 与最新版本相同才算这个软件的旧版本——否则会把
          VC++ 2019 与 2022 这种**可以并存的不同产品**误报成旧版本，诱导用户卸掉仍在用的运行库。
        - `RecordKey`：单独移除该版本的入口——系统安装记录（Uninstall 键）的路径。
          文件类检测只知道「还有这个版本的文件」，由调用方按版本号反查对应的安装记录补上；
          查不到时为空，界面如实说明只能手动卸载。
    .OUTPUTS
        无（原地往 $Result.Versions 追加）
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Result,
        [string]$Version = '',
        [string]$Detail = '',
        [string]$RecordKey = '',
        [string]$GroupKey = ''
    )

    if (-not $Version) { return }
    $items = @()
    if ($null -ne $Result['Versions']) { $items = @($Result['Versions']) }
    $Result['Versions'] = @($items + @([ordered]@{
        Version   = $Version
        Detail    = $Detail
        RecordKey = $RecordKey
        GroupKey  = $GroupKey
    }))
}
