#Requires -Version 5.1

function Get-WinstVersionFromText {
    <#
    .SYNOPSIS
        按 detect 的 versionKind / versionBetween 从文本里取版本；未声明识别器时只在「文本本身就是一个版本号」时才原样返回。
    .DESCRIPTION
        未声明识别器时**不能**无脑把整段原文当版本：调用方传进来的常常是整份文件内容 / 一整段命令输出 /
        一个安装包文件名，原样返回会让「检测到的版本」变成一大段文本（再被记进台账、参与版本比较）。
        但也不能一律返回空：registry 的 DisplayVersion、appx 的 Version、文件的 FileVersion 这些值
        **本身就是版本号**（如 `1.8.0_504-b01`），截断成 `1.8.0` 会让不同构建被误判成同一版本。
        因此按「单行 + 版本号形状」判定：像版本号就原样返回，像文档则返回空由调用方决定兜底
        （从任意文本里捞版本号请显式用 Get-WinstFirstVersionLike）。
    .OUTPUTS
        [string]
    #>
    param([string]$Text, [string]$Kind, $Between)

    if ($null -eq $Text) { return '' }
    $value = [string]$Text
    # 先按标记截取、再按识别器提取（两者都声明时可组合；只声明其一时与旧行为一致，见 Get-VersionFromSourceText）
    if ($Between -and @($Between).Count -gt 0) {
        $r = Get-VersionBetween -Spec $Between -Text $value
        if (-not $r.Ok) { return '' }
        $value = [string]$r.Value
    }
    if ($Kind) { return (Get-VersionValue -Text $value -Kind $Kind) }
    # 只声明了 versionBetween（截取出来的那一段就是版本）、没有识别器的，按截取结果返回
    if ($Between -and @($Between).Count -gt 0) { return $value.Trim() }

    $trimmed = $value.Trim()
    if (-not $trimmed) { return '' }
    return (Format-WinstBareVersionValue -Text $trimmed)
}
