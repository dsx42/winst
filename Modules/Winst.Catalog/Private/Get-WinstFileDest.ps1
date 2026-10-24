#Requires -Version 5.1

function Get-WinstFileDest {
    <#
    .SYNOPSIS
        取 files[] 条目的落位路径（dest）；主包的 dest 无意义，统一忽略并记一条提示。
    .DESCRIPTION
        六个来源解析器（direct / github / listing / page / json / magnet）原本各自复制这段判断，
        现集中到一处：规则调整（提示文案、是否允许主包 dest）只改这里。
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
