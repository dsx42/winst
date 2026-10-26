#Requires -Version 5.1

function Test-WinstShortcutMatches {
    <#
    .SYNOPSIS
        判断一个已有 .lnk 是否已经指向期望的目标 / 起始位置。

    .DESCRIPTION
        只比对**目标程序**与**起始位置**两项：
        - 目标不同 = 快捷方式坏了（安装位置换过、被别人改过、旧版本残留），必须重建；
        - 起始位置不同 = 有些程序要求工作目录正确（相对路径读配置 / 数据），也一并修正。

        备注（Description）不参与判断：它只影响鼠标悬停提示，用来决定「是否重建」
        会让每次安装都白写一次文件。

        路径比较统一走 `[IO.Path]::GetFullPath` 后按 OrdinalIgnoreCase 比对，
        规避 `C:\a\..\a`、尾部反斜杠、相对路径这些写法差异带来的假「不一致」。

    .OUTPUTS
        [bool] 目标与起始位置都一致时为 $true
    #>
    param(
        [Parameter(Mandatory = $true)][string]$LinkPath,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [string]$WorkingDirectory = ''
    )

    $info = Get-WinstShortcutInfo -LinkPath $LinkPath
    if (-not $info.Ok) { return $false }

    $normalize = {
        param([string]$Value)
        if (-not $Value) { return '' }
        $text = $Value.Trim().Trim('"')
        if (-not $text) { return '' }
        try { return ([IO.Path]::GetFullPath($text)).TrimEnd('\', '/') } catch { return $text.TrimEnd('\', '/') }
    }

    $expectedTarget = & $normalize $TargetPath
    $actualTarget = & $normalize ([string]$info.TargetPath)
    if (-not $actualTarget) { return $false }
    if ($expectedTarget -ine $actualTarget) { return $false }

    # 起始位置：期望为空时不参与比较（清单没要求工作目录，用什么都不算错）
    $expectedDir = & $normalize $WorkingDirectory
    if ($expectedDir) {
        $actualDir = & $normalize ([string]$info.WorkingDirectory)
        if ($expectedDir -ine $actualDir) { return $false }
    }

    return $true
}
