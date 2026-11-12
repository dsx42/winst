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
    $values = @{ '{installDir}' = $InstallDir; '{installRoot}' = $InstallRoot }
    # 从后向前替换原模板的命中点，插入的路径不再作为模板解析。
    $hits = [regex]::Matches($text, '\{installDir\}|\{installRoot\}')
    for ($hitIndex = $hits.Count - 1; $hitIndex -ge 0; $hitIndex--) {
        $hit = $hits[$hitIndex]
        $value = [string]$values[$hit.Value]
        if (-not $value) { continue }
        $before = $text.Substring(0, $hit.Index)
        $after = $text.Substring($hit.Index + $hit.Length)
        if (Get-WinstCommandLineQuoteState -Text $before) {
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
    }
    if (-not (Test-WinstArgumentTemplateSafe -Value $text)) {
        $result.Error = '安装参数展开后双引号不匹配'
        return $result
    }
    $result.Ok = $true
    $result.Value = $text
    return $result
}
