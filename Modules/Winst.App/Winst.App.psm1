#Requires -Version 5.1
<#
    Winst.App 模块加载器。

    加载顺序：
        1. Private\**\*.ps1   内部辅助函数，不导出
        2. Public\**\*.ps1    导出函数

    文件按路径排序后依次加载。函数文件只能定义函数，不能在加载期执行逻辑，
    因为它调用的其它函数可能还没加载。

    导出名单由 Public 目录的 AST 收集，因此新增 Public\*.ps1 不需要改这里。
#>

Set-StrictMode -Version 2

$script:ModuleRoot  = $PSScriptRoot
$script:PublicRoot  = Join-Path -Path $PSScriptRoot -ChildPath 'Public'
$script:PrivateRoot = Join-Path -Path $PSScriptRoot -ChildPath 'Private'

function Get-WinstFunctionFilePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return @()
    }

    return @(
        Get-ChildItem -LiteralPath $Path -Filter '*.ps1' -File -Recurse -ErrorAction Stop |
        Sort-Object -Property FullName
    )
}

function Get-WinstPublicFunctionName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $names = New-Object 'System.Collections.Generic.List[string]'
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return $names
    }

    foreach ($file in @(Get-ChildItem -LiteralPath $Path -Filter '*.ps1' -File -Recurse -ErrorAction Stop | Sort-Object -Property FullName)) {
        $tokens = $null
        $parseErrors = $null

        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $file.FullName,
            [ref]$tokens,
            [ref]$parseErrors
        )

        if ($parseErrors -and $parseErrors.Count -gt 0) {
            throw ('{0}: 语法错误：{1}' -f $file.FullName, $parseErrors[0].Message)
        }

        $definitions = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
        }, $true)

        foreach ($definition in $definitions) {
            $names.Add($definition.Name)
        }
    }

    return $names
}

# 点源必须在模块顶层执行，不能放进函数：
# 函数内的点源会把函数定义在该函数的局部作用域，函数返回后即消失。
foreach ($file in @(Get-WinstFunctionFilePath -Path $script:PrivateRoot)) {
    . $file.FullName
}

foreach ($file in @(Get-WinstFunctionFilePath -Path $script:PublicRoot)) {
    . $file.FullName
}

# 用 @() 包一层：只导出一个函数时结果是字符串，
# 字符串上的 .Count 在 Set-StrictMode -Version 2 下会报错。
$publicFunctions = @(Get-WinstPublicFunctionName -Path $script:PublicRoot)

if ($publicFunctions.Count -eq 0) {
    throw ('模块 {0} 没有导出任何函数；Public 目录是空的。' -f $script:ModuleRoot)
}

$unique = @($publicFunctions | Select-Object -Unique)

Export-ModuleMember -Function $unique