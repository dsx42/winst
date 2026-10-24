#Requires -Version 5.1

function Set-WinstDetectedVersionFromRaw {
    <#
    .SYNOPSIS
        把「检测到的原始文本」按识别规则转成版本号并写进检测结果（六种 detect.method 共用）。
    .DESCRIPTION
        六种 detect.method 共用这四步：Get-WinstVersionFromText → 兜底 Get-WinstFirstVersionLike →
        写 Detail → 命中才写 Ok/Version。兜底条件用 -Fallback 显式表达：
          whenNoKind（默认）：只有未声明 versionKind / versionBetween 时才兜底
                              （registry / fileVersion / jsonFile / appx / cli 用）
          always            ：无条件兜底（markerFile 用：标记文件内容常常就是版本号本身）
          none              ：完全不兜底（调用方自己处理）
        无论是否命中都会写 Result.Found（调用方已确认「找到了目标」时先置真）。
    .OUTPUTS
        无（原地写 $Result 的 Ok / Version / Detail）
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Result,
        [string]$Raw = '',
        [string]$Kind = '',
        $Between = @(),
        [string]$Detail = '',
        [ValidateSet('whenNoKind', 'always', 'none')][string]$Fallback = 'whenNoKind'
    )

    $betweenCount = @($Between).Count
    $value = Get-WinstVersionFromText -Text $Raw -Kind $Kind -Between $Between
    if (-not $value) {
        $allowFallback = $false
        if ($Fallback -eq 'always') { $allowFallback = $true }
        elseif ($Fallback -eq 'whenNoKind') { $allowFallback = (-not $Kind -and $betweenCount -eq 0) }
        if ($allowFallback) { $value = Get-WinstFirstVersionLike -Text $Raw }
    }

    if ($Detail) { $Result.Detail = $Detail }
    if (-not $value) { return }
    $Result.Ok = $true
    $Result.Version = $value
}
