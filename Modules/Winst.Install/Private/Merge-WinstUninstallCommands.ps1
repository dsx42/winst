#Requires -Version 5.1

function Merge-WinstUninstallCommands {
    <#
    .SYNOPSIS
        卸载命令：两处定义合并，同一条命令只执行一次（exe + args 相同即视为同一条）。
    .OUTPUTS
        [array]
    #>
    param($RecordSnapshot, $ManifestSnapshot)

    $commands = @()
    $commandSeen = New-Object 'System.Collections.Hashtable' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($commandList in @(@($RecordSnapshot['commands']), @($ManifestSnapshot['commands']))) {
        foreach ($item in @($commandList)) {
            $exeText = (Get-EntryString -Entry $item -Key 'exe').Trim()
            if (-not $exeText) { continue }
            $argsText = (Get-EntryString -Entry $item -Key 'args').Trim()
            $key = $exeText + '|' + $argsText
            if ($commandSeen.ContainsKey($key)) { continue }
            $commandSeen[$key] = $true
            $commandBlock = [ordered]@{
                exe        = $exeText
                args       = $argsText
                timeoutSec = (Get-EntryInt -Entry $item -Key 'timeoutSec' -Default 600)
            }
            if (Get-EntryBool -Entry $item -Key 'requireAdmin') { $commandBlock['requireAdmin'] = $true }
            $commands += $commandBlock
        }
    }
    return $commands
}
