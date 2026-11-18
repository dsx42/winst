#Requires -Version 5.1
# 在调用模块作用域点源，以该模块目录定位函数文件。
param([string]$ModuleDirectory)

Set-StrictMode -Version 2

$script:PublicRoot  = Join-Path -Path $ModuleDirectory -ChildPath 'Public'
$script:PrivateRoot = Join-Path -Path $ModuleDirectory -ChildPath 'Private'

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
    param([IO.FileInfo[]]$Files)

    $names = New-Object 'System.Collections.Generic.List[string]'
    foreach ($file in $Files) {
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

$publicFiles = @(Get-WinstFunctionFilePath -Path $script:PublicRoot)
foreach ($file in $publicFiles) {
    . $file.FullName
}

# 用 @() 包一层：只导出一个函数时结果是字符串，
# 字符串上的 .Count 在 Set-StrictMode -Version 2 下会报错。
$publicFunctions = @(Get-WinstPublicFunctionName -Files $publicFiles)

if ($publicFunctions.Count -eq 0) {
    throw ('模块 {0} 没有导出任何函数；Public 目录是空的。' -f $ModuleDirectory)
}

$unique = @($publicFunctions | Select-Object -Unique)

Export-ModuleMember -Function $unique