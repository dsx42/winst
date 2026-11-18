#Requires -Version 5.1

function Get-WinstFileMapKey {
    param([Collections.IDictionary]$Map, [string]$Name)
    if ($Map.Contains($Name) -or $Map.PSObject.TypeNames[0] -eq 'Winst.FileNameMap') { return $Name }
    # 外部调用可传入区分大小写的字典，兼容不同拼写的文件名。
    foreach ($key in $Map.Keys) { if ([string]$key -ieq $Name) { return [string]$key } }
    return $Name
}
