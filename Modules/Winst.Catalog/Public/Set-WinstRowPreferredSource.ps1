#Requires -Version 5.1

function Set-WinstRowPreferredSource {
    <#
    .SYNOPSIS
        把软件清单行里的某个来源挪到最前面（更新时优先用安装记录里的来源）；未命中返回原行。
    #>
    param($Row, [string]$SourceName)

    if (-not $Row -or -not $SourceName) { return $Row }
    $sources = @($Row['Sources'])
    if ($sources.Count -le 1) { return $Row }

    $first = $null
    $rest = @()
    foreach ($entry in $sources) {
        if ((-not $first) -and ([string]$entry['Source'] -ieq $SourceName)) { $first = $entry } else { $rest += $entry }
    }
    if (-not $first) { return $Row }

    return [ordered]@{
        Id          = $Row['Id']
        Name        = $Row['Name']
        Description = $Row['Description']
        Sources     = @(@($first) + @($rest))
    }
}
