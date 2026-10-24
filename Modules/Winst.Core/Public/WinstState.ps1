#Requires -Version 5.1
<#
    WinstState.ps1  (Winst.Core / Public)

    跨模块状态容器（在 Private\WinstState.Type.ps1 中声明）的公开 API。

    所有模块都通过这些函数访问状态，不直接碰 $script:Winst* 变量，
    存储方式因此只是实现细节。
#>

function Get-WinstState {
    <#
    .SYNOPSIS
        读取跨模块状态值。

    .DESCRIPTION
        从未设置过的名字返回 $null。调用方不能假设它有默认值，
        见 Initialize-WinstState。

        **空集合也是有效值**：状态里存的数组 / 列表即使为空，也必须能原样取回。
        管道输出会把空集合展开成「没有任何输出」，调用方拿到的就是 $null，
        于是「缓存了一次空结果」和「从没缓存过」无法区分（缓存会被无限重建）。
        因此这里用 -NoEnumerate 输出，保证存进去什么就取回什么。
        判断「是否设置过」用 Test-WinstState，不靠 $null 判断。

    .OUTPUTS
        [object]
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    Write-Output -NoEnumerate ([Winst.State]::Get($Name))
}

function Set-WinstState {
    <#
    .SYNOPSIS
        写入跨模块状态值并返回它。

    .DESCRIPTION
        返回存入的值，因此

            $local = Set-WinstState -Name WinstFoo -Value <表达式>

        一行即可同时完成赋值与取值，不需要第二条语句。

    .OUTPUTS
        [object] 存入的值
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [object]$Value = $null
    )

    [Winst.State]::Set($Name, $Value)
    return $Value
}

function Test-WinstState {
    <#
    .SYNOPSIS
        判断某个状态名当前是否已设置。

    .OUTPUTS
        [bool]
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return [Winst.State]::Contains($Name)
}

function Remove-WinstState {
    <#
    .SYNOPSIS
        移除一个状态项。

    .OUTPUTS
        [bool] 确实移除了项时为 $true
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    return [Winst.State]::Remove($Name)
}

function Reset-WinstState {
    <#
    .SYNOPSIS
        清空全部状态项。

    .DESCRIPTION
        用于开始一轮全新的菜单会话。
    #>
    [CmdletBinding()]
    param()

    [Winst.State]::Clear()
}
