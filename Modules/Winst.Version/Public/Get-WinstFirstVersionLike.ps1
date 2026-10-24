#Requires -Version 5.1

function Get-WinstFirstVersionLike {
    <#
    .SYNOPSIS
        从文本里识别第一个「像版本号」的内容（semver → date → digits），用于未声明识别器的标记文件 / 命令输出。
    #>
    param([string]$Text)

    if (-not $Text) { return '' }
    foreach ($kind in @('semver', 'date', 'digits')) {
        $v = Get-VersionValue -Text $Text -Kind $kind
        if ($v) { return $v }
    }
    return ''
}
