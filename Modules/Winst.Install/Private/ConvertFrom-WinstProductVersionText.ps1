#Requires -Version 5.1
<#
    ConvertFrom-WinstProductVersionText.ps1  (Winst.Install / Private)

    从「定义了 Get-WinstProductVersion 的源码文本」里取出该函数的返回值。

    为什么按文本读、不点源
    ----------------------
    点源那个文件会在模块里再定义一个 Get-WinstProductVersion，遮蔽真正的那个；
    而对外报版本时是从自己加载的代码里拿的，两边必须一致。读文本不会污染当前会话。

    为什么用 AST 而不是正则
    -----------------------
    这段源码里有很多字符串（仓库 URL、清单地址等），`return '([^']+)'` 之类的
    模式很容易匹到别的地方。因此从具名函数的 return 语句上取值。

    两种输入形态
    ------------
        开发树 / 已解压目录 : Modules\Winst.Core\Public\WinstConstants.ps1
        release 单一模块     : Modules\Winst\Winst.psm1
    两种文本都定义了 Get-WinstProductVersion，本函数对二者一视同仁。

    .OUTPUTS
        [string] 版本号，找不到该函数或取不到值时为空串
#>
function ConvertFrom-WinstProductVersionText {
    <#
    .SYNOPSIS
        从源码文本里读出 Get-WinstProductVersion 的字符串返回值。

    .PARAMETER Text
        含 Get-WinstProductVersion 定义的源码文本。

    .OUTPUTS
        [string]
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$Text)

    if (-not $Text) { return '' }

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput(
        $Text, 'winst', [ref]$tokens, [ref]$parseErrors)

    if ($parseErrors -and $parseErrors.Count -gt 0) { return '' }

    $definitions = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'Get-WinstProductVersion'
        }, $true)

    foreach ($definition in $definitions) {
        $returns = $definition.Body.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.ReturnStatementAst]
            }, $true)

        foreach ($statement in $returns) {
            $pipeline = $statement.Pipeline
            if (-not $pipeline) { continue }
            foreach ($element in @($pipeline.PipelineElements)) {
                $expression = $element.Expression
                if ($expression -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                    $value = ([string]$expression.Value).Trim()
                    if ($value) { return $value }
                }
            }
        }
    }

    return ''
}
