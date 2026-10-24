#Requires -Version 5.1

function Get-DisplayWidth {
    <#
    .SYNOPSIS
        估算字符串在终端中的显示宽度（中日韩等全角字符按 2 列计）。
    #>
    param(
        [string]$Text
    )

    if (-not $Text) { return 0 }

    $width = 0
    foreach ($ch in $Text.ToCharArray()) {
        $code = [int]$ch
        # 组合字符 / 零宽字符不占列
        if (($code -ge 0x0300 -and $code -le 0x036F) -or $code -eq 0x200B) { continue }
        # East Asian Wide / Fullwidth 区间（CJK、假名、谚文、全角符号）；
        # 不用「> 0x2000 即全角」的粗判：… ↑ — → 等常见标点在终端里只占 1 列，按 2 列算会让菜单说明列错位
        if (($code -ge 0x1100 -and $code -le 0x115F) -or
            ($code -ge 0x2E80 -and $code -le 0xA4CF) -or
            ($code -ge 0xAC00 -and $code -le 0xD7A3) -or
            ($code -ge 0xF900 -and $code -le 0xFAFF) -or
            ($code -ge 0xFE30 -and $code -le 0xFE6F) -or
            ($code -ge 0xFF00 -and $code -le 0xFF60) -or
            ($code -ge 0xFFE0 -and $code -le 0xFFE6)) { $width += 2; continue }
        $width += 1
    }
    return $width
}
