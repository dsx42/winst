#Requires -Version 5.1

function Read-WinstCommandLine {
    <#
    .SYNOPSIS
        解析命令行：抽出全局参数，剩下的按「命令 + 命令参数」返回。
    .DESCRIPTION
        全局参数**写在命令之前或之后都支持**（`winst --pkg-dir D:\pkg list` 与
        `winst list --pkg-dir D:\pkg` 等价）：两种位置都会从命令参数里摘掉，交给全局选项；
        开关支持 `--pkg-dir <路径>` 与 `--pkg-dir=<路径>` 两种写法。
        命令自己认识的开关（如 `--force` / `--keep` / `--check`）原样保留，不会误吃。
    .OUTPUTS
        @{ Options; Command; Arguments; Error }
    #>
    param([string[]]$Tokens, [hashtable]$InitialOptions = $null)

    $options = New-WinstCliOptions
    if ($InitialOptions) { foreach ($key in @($InitialOptions.Keys)) { $options[$key] = $InitialOptions[$key] } }
    $command = ''
    $rest = @()
    $optionKeys = @{ '--install-root' = 'InstallRoot'; '--pkg-dir' = 'PkgDir'; '--proxy' = 'Proxy' }
    $error = ''

    for ($i = 0; $null -ne $Tokens -and $i -lt $Tokens.Length; $i++) {
        $text = [string]$Tokens[$i]
        $option = ($text -split '=', 2)[0]
        if ($optionKeys.ContainsKey($option)) {
            $value = Read-WinstCliOptionValue -Tokens $Tokens -Index ([ref]$i)
            if (-not $value) { $error = ('{0} 缺少取值，请写成 {0} <值> 或 {0}=<值>。' -f $option); break }
            $options[$optionKeys[$option]] = $value
            continue
        }
        # 在摘走全局开关前检查子命令的相邻取值，防止把后面的 id 补成取值。
        if ((($command -in @('install', 'download')) -and ($option -in @('--source','--from','--keep'))) -or
            ($command -eq 'update' -and $option -eq '--source')) {
            $start = $i
            if (-not (Read-WinstCliOptionValue -Tokens $Tokens -Index ([ref]$i))) {
                $error = ('{0} 缺少取值，请写成 {0} <值> 或 {0}=<值>。' -f $option)
                break
            }
            $rest += $Tokens[$start..$i]
            continue
        }
        if ($text -ieq '--offline') { $options.Offline = $true; continue }
        if ($text -ieq '--dry-run') { $options.DryRun = $true; continue }
        if ($text -ieq '--yes' -or $text -ieq '-y') { $options.Yes = $true; continue }
        if ($text -ieq '--verbose') { $options.Verbose = $true; continue }

        # 还没有命令名：遇到 -v / -h 这类「本身就是完整命令」的开关时它就是命令，
        # 后面的 token 只是它的参数（`winst -v repair` 仍然是「查看版本」，不展开成 repair）。
        # 遇到其它未识别的开关立即报错，非开关参数作为命令名。
        if (-not $command) {
            if ($text.StartsWith('-')) {
                if (Test-WinstReadOnlyCommand -Name $text) {
                    $command = $text
                    continue
                }
                $error = ('未知参数: {0}' -f $text)
                break
            }
            $command = $text
            continue
        }

        # 命令之后的开关：全局参数已在上方摘走，其余原样交给该命令自己解析（如 update --check、list --cached）
        $rest += $text
    }

    return @{ Options = $options; Command = $command; Arguments = @($rest); Error = $error }
}
