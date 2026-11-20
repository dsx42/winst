#Requires -Version 5.1

function Get-WinstListCommandTarget {
    <#
    .SYNOPSIS
        CLI 用：把命令行给的清单参数解析成清单文件路径（缺省 = lists\<默认文件名>）。
    .OUTPUTS
        @{ Ok; Error; Path }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string]$Text = ''
    )

    $defaultName = (Get-WinstListFileName)
    if (-not $Text) {
        return @{ Ok = $true; Error = ''; Path = (Join-WinstPath (Get-WinstListsDir -Context $Context) $defaultName) }
    }
    $resolved = Resolve-WinstListPath -Context $Context -Text $Text
    if (-not $resolved.Ok) { return @{ Ok = $false; Error = $resolved.Error; Path = '' } }
    return @{ Ok = $true; Error = ''; Path = $resolved.Path }
}
