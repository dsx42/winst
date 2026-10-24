#Requires -Version 5.1

function Split-WinstCommandLine {
    <#
    .SYNOPSIS
        把系统安装记录里的命令行拆成「程序路径 + 参数」（去掉包裹引号）。
    .OUTPUTS
        @{ Ok; Exe; Args }
    #>
    param([string]$Text)

    $result = @{ Ok = $false; Exe = ''; Args = '' }
    if (-not $Text) { return $result }
    $value = ([string]$Text).Trim()
    if (-not $value) { return $result }

    if ($value.StartsWith('"')) {
        $end = $value.IndexOf('"', 1)
        if ($end -gt 1) {
            $result.Exe = $value.Substring(1, $end - 1)
            $result.Args = $value.Substring($end + 1).Trim()
            $result.Ok = $true
            return $result
        }
    }

    $index = $value.IndexOf('.exe', [StringComparison]::OrdinalIgnoreCase)
    if ($index -ge 0) {
        $result.Exe = $value.Substring(0, $index + 4).Trim()
        $result.Args = $value.Substring($index + 4).Trim()
        $result.Ok = $true
        return $result
    }

    $spaceIndex = $value.IndexOf(' ')
    if ($spaceIndex -gt 0) {
        $result.Exe = $value.Substring(0, $spaceIndex).Trim()
        $result.Args = $value.Substring($spaceIndex + 1).Trim()
        $result.Ok = $true
        return $result
    }

    $result.Exe = $value
    $result.Ok = $true
    return $result
}
