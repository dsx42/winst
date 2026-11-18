#Requires -Version 5.1

function Sort-WinstRegistryMatches {
    param($Hits, [string]$InstallDir)

    $preferred = @()
    $others = @()
    if ($InstallDir) {
        $expected = ([string]$InstallDir).TrimEnd('\')
        foreach ($hit in $hits) {
            $location = ConvertTo-WinstDirPath -Text (Get-EntryString -Entry $hit -Key 'InstallLocation')
            if ($location -and $location -ieq $expected) { $preferred += $hit } else { $others += $hit }
        }
    } else {
        $others = @($hits)
    }
    $sorted = @($others | Sort-Object -Property @{ Expression = { [string]$_['DisplayName'] } })
    return @(@($preferred) + @($sorted))
}
