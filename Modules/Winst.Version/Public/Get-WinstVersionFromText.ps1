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

    # 两者都声明时，先截取，再按识别器提取。
    if ($Between -and @($Between).Count -gt 0) {
        $r = Get-VersionBetween -Spec $Between -Text $Text
        if (-not $r.Ok) { return '' }
        if (-not $Kind) { return $r.Value }
        $Text = $r.Value
    }
    if ($Kind) { return (Get-VersionValue -Text $Text -Kind $Kind) }
    return (Format-WinstBareVersionValue -Text $Text)
}
