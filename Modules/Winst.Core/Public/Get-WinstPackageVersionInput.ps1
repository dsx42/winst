#Requires -Version 5.1

function Get-WinstPackageVersionInput {
    <#
    .SYNOPSIS
        选择实际取版文件，通配命中多个声明时按文件名排序，未命中则选主包。
    #>
    param($Plan)

    $files = @(Get-EntryArray -Entry (Get-EntryValue -Entry $Plan -Key 'download') -Key 'files')
    $rule = (Get-EntryString -Entry (Get-EntryValue -Entry $Plan -Key 'packageVersion') -Key 'file').Trim()
    $selected = $null
    for ($i = 0; $i -lt $files.Count; $i++) {
        $url = Get-EntryString -Entry $files[$i] -Key 'url'
        $name = Get-EntryString -Entry $files[$i] -Key 'name'
        if (-not $name) { $name = Get-FileNameFromUrl -Url $url }
        $name = $name.Trim()
        if (-not $name -or -not (Test-WinstSafePathSegment -Name $name)) { continue }
        if ($i -eq 0 -or ($rule -and $name -like $rule -and
                (-not $selected -or $selected.Name -notlike $rule -or $name -ilt $selected.Name))) {
            $selected = @{ Index = $i; Name = $name }
        }
    }
    return $selected
}