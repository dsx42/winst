#Requires -Version 5.1

function Get-DisplayWidth {
    <#
    .SYNOPSIS
        估算 Windows Terminal 常见字形的列宽（全角与合成 emoji 按 2 列计）。
    #>
    param(
        [string]$Text
    )

    if (-not $Text) { return 0 }

    $width = 0
    $clusterWidth = 0
    $emojiCluster = $false
    $joinNext = $false
    $regionalCount = 0
    # shortcut: 按常见 emoji 序列估宽，终端或字体不合成字形时需按实测扩展规则。
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $category = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($Text, $i)
        $code = [int]$Text[$i]
        if ([char]::IsHighSurrogate($Text[$i]) -and $i + 1 -lt $Text.Length -and [char]::IsLowSurrogate($Text[$i + 1])) {
            $code = [char]::ConvertToUtf32($Text, $i)
            $i++
        }
        if ($code -eq 0x200D) { $joinNext = $emojiCluster; continue }
        if ($code -eq 0xFE0F -or $code -eq 0x20E3) {
            if ($clusterWidth -gt 0) { $clusterWidth = 2; $emojiCluster = $true }
            continue
        }
        if ($category -in @('NonSpacingMark', 'SpacingCombiningMark', 'EnclosingMark', 'Format', 'Control') -or
            ($code -ge 0x1F3FB -and $code -le 0x1F3FF)) { continue }

        $regional = ($code -ge 0x1F1E6 -and $code -le 0x1F1FF)
        $emoji = ($code -ge 0x1F000 -and $code -le 0x1FAFF)
        $charWidth = 1
        # 中日韩全角区间；… ↑ — → 等常见标点仍按 1 列计。
        if ($emoji -or ($code -ge 0x1100 -and $code -le 0x115F) -or
            ($code -ge 0x2E80 -and $code -le 0xA4CF) -or
            ($code -ge 0xAC00 -and $code -le 0xD7A3) -or
            ($code -ge 0xF900 -and $code -le 0xFAFF) -or
            ($code -ge 0xFE30 -and $code -le 0xFE6F) -or
            ($code -ge 0xFF00 -and $code -le 0xFF60) -or
            ($code -ge 0xFFE0 -and $code -le 0xFFE6) -or
            ($code -ge 0x20000 -and $code -le 0x3FFFD)) { $charWidth = 2 }

        if (($joinNext -and ($emoji -or ($code -ge 0x2600 -and $code -le 0x27BF))) -or
            ($regional -and $regionalCount -eq 1)) {
            $clusterWidth = [Math]::Max($clusterWidth, $charWidth)
        } else {
            $width += $clusterWidth
            $clusterWidth = $charWidth
        }
        $emojiCluster = $emoji -or ($code -ge 0x2600 -and $code -le 0x27BF)
        $joinNext = $false
        if ($regional) { $regionalCount = ($regionalCount + 1) % 2 } else { $regionalCount = 0 }
    }
    return ($width + $clusterWidth)
}
