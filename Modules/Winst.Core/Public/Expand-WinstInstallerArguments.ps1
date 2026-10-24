#Requires -Version 5.1

function Expand-WinstInstallerArguments {
    <#
    .SYNOPSIS
        展开安装参数里的路径占位符，并在占位符未被引号包围时按单个参数安全加引号。
    .OUTPUTS
        @{ Ok; Value; Error }
    #>
    param(
        [string]$Template,
        [string]$InstallDir,
        [string]$InstallRoot = ''
    )

    $result = @{ Ok = $false; Value = ''; Error = '' }
    if (-not (Test-WinstArgumentTemplateSafe -Value $Template)) {
        $result.Error = '安装参数含有控制字符或未闭合的双引号'
        return $result
    }
    foreach ($path in @($InstallDir, $InstallRoot)) {
        if ($path -and -not (Test-WinstArgumentSafe -Value $path)) {
            $result.Error = ('安装路径含有无法安全传给安装程序的字符：{0}' -f $path)
            return $result
        }
    }

    $text = [string]$Template
    $values = [ordered]@{ '{installDir}' = $InstallDir; '{installRoot}' = $InstallRoot }
    foreach ($placeholder in @($values.Keys)) {
        $value = [string]$values[$placeholder]
        if (-not $value) { continue }
        $searchFrom = 0
        while ($true) {
            $index = $text.IndexOf($placeholder, $searchFrom, [StringComparison]::Ordinal)
            if ($index -lt 0) { break }
            $before = $text.Substring(0, $index)
            $after = $text.Substring($index + $placeholder.Length)
            $insideQuotes = Get-WinstCommandLineQuoteState -Text $before
            if ($insideQuotes) {
                $replacement = $value
                if ($after.StartsWith('"')) {
                    $trailing = 0
                    for ($i = $replacement.Length - 1; $i -ge 0 -and $replacement[$i] -eq '\'; $i--) { $trailing++ }
                    if ($trailing -gt 0) { $replacement += (('\' * $trailing) -join '') }
                }
            } else {
                $replacement = Format-WinstCommandArgument -Value $value
            }
            $text = $before + $replacement + $after
            $searchFrom = $before.Length + $replacement.Length
        }
    }
    if (-not (Test-WinstArgumentTemplateSafe -Value $text)) {
        $result.Error = '安装参数展开后双引号不匹配'
        return $result
    }
    $result.Ok = $true
    $result.Value = $text
    return $result
}
