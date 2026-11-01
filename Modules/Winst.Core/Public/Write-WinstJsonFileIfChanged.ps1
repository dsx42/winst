#Requires -Version 5.1

function Write-WinstJsonFileIfChanged {
    <#
    .SYNOPSIS
        JSON 内容变化时原子写入，返回是否写盘；对象键顺序与排版差异不触发写入。
    .DESCRIPTION
        内容相同时保留文件修改时间和 JSON 缓存。现有 JSON 损坏时写入有效的新内容。
        文件读取或写入错误向调用方抛出。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)]$InputObject,
        [int]$Depth = 12
    )

    $content = ConvertTo-WinstJson -InputObject $InputObject -Depth $Depth
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        $existingText = [IO.File]::ReadAllText($Path)
        if ([string]::Equals($existingText, $content, [StringComparison]::Ordinal)) { return $false }
        $canCompare = $false
        $existingValue = $null
        try {
            $existingValue = ConvertFrom-Json -InputObject $existingText -ErrorAction Stop
            $canCompare = $true
        } catch {
            Write-Verbose ('现有文件不是有效 JSON，将写入新内容：{0}' -f $Path)
        }
        if ($canCompare) {
            $newValue = ConvertFrom-Json -InputObject $content -ErrorAction Stop
            if (Test-WinstJsonValueEqual -Left $existingValue -Right $newValue) { return $false }
        }
    }
    Write-FileAtomic -Path $Path -Content $content
    return $true
}
