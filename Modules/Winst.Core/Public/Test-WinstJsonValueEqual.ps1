#Requires -Version 5.1

function Test-WinstJsonValueEqual {
    <#
    .SYNOPSIS
        比较 JSON 解析值：对象键顺序不影响结果，键名与字符串区分大小写，数组按顺序比较。
    #>
    param($Left, $Right)

    if ([object]::ReferenceEquals($Left, $Right)) { return $true }
    if ($null -eq $Left -or $null -eq $Right) {
        return ($null -eq $Left -and $null -eq $Right)
    }
    $leftObject = ($Left -is [System.Collections.IDictionary] -or $Left -is [pscustomobject])
    $rightObject = ($Right -is [System.Collections.IDictionary] -or $Right -is [pscustomobject])
    if ($leftObject -or $rightObject) {
        if (-not ($leftObject -and $rightObject)) { return $false }
        if ($Left -isnot [System.Collections.IDictionary] -and $Right -is [System.Collections.IDictionary]) {
            $keys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            foreach ($key in $Right.Keys) { $null = $keys.Add([string]$key) }
            $count = 0
            foreach ($prop in $Left.PSObject.Properties) {
                $count++
                if (-not $keys.Contains($prop.Name) -or -not (Test-WinstJsonValueEqual -Left $prop.Value -Right $Right[$prop.Name])) { return $false }
            }
            return ($count -eq $Right.Count)
        }
        $leftMap = New-WinstOrdinalDictionary
        $rightMap = New-WinstOrdinalDictionary
        foreach ($pair in @(Get-WinstEntryPairs -Entry $Left)) { $leftMap[[string]$pair[0]] = $pair[1] }
        foreach ($pair in @(Get-WinstEntryPairs -Entry $Right)) { $rightMap[[string]$pair[0]] = $pair[1] }
        if ($leftMap.Count -ne $rightMap.Count) { return $false }
        foreach ($key in @($leftMap.Keys)) {
            if (-not $rightMap.Contains($key)) { return $false }
            if (-not (Test-WinstJsonValueEqual -Left $leftMap[$key] -Right $rightMap[$key])) { return $false }
        }
        return $true
    }
    $leftArray = $Left -is [System.Collections.IList]
    $rightArray = $Right -is [System.Collections.IList]
    if ($leftArray -or $rightArray) {
        if (-not ($leftArray -and $rightArray)) { return $false }
        if ($Left.Count -ne $Right.Count) { return $false }
        for ($i = 0; $i -lt $Left.Count; $i++) {
            if (-not (Test-WinstJsonValueEqual -Left $Left[$i] -Right $Right[$i])) { return $false }
        }
        return $true
    }
    if (($Left -is [int] -or $Left -is [long]) -and ($Right -is [int] -or $Right -is [long])) {
        return ([long]$Left -eq [long]$Right)
    }
    return [object]::Equals($Left, $Right)
}
