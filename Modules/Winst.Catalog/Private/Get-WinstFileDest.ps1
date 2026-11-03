#Requires -Version 5.1

function Get-WinstFileDest {
    <#
    .SYNOPSIS
        取 files[] 条目的落位路径（dest）；主包的 dest 无意义，统一忽略并记一条提示。
    .DESCRIPTION
        来源解析器共用此规则：主包按类型安装，dest 仅用于附加文件。
    .OUTPUTS
        [string] 实际生效的 dest（主包或未声明时为空串）
    #>
    param(
        [Parameter(Mandatory = $true)]$Item,
        [int]$Index = 1,
        [Parameter(Mandatory = $true)]$Result
    )

    $dest = Get-EntryString -Entry $Item -Key 'dest'
    if ($Index -eq 1 -and $dest) {
        $Result.Notes += (Get-WinstMainFileDestNote)
        return ''
    }
    return $dest
}
