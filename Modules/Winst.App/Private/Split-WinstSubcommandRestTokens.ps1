#Requires -Version 5.1

function Split-WinstSubcommandRestTokens {
    <#
    .SYNOPSIS
        解析子命令之后的 token：识别可选 --all（通用开关已由正式解析器消费），返回 positional 与其余标志。
    .OUTPUTS
        @{ Positional; Offline; All }
    #>
    param(
        [string[]]$Rest,
        [switch]$IncludeAll
    )

    $offline = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Offline)
    $all = $false
    $positional = @()
    foreach ($token in @($Rest)) {
        $text = [string]$token
        if ($IncludeAll -and $text -eq '--all') { $all = $true; continue }
        $positional += $text
    }
    return @{ Positional = $positional; Offline = $offline; All = $all }
}
