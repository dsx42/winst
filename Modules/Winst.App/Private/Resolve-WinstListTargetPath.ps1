#Requires -Version 5.1

function Resolve-WinstListTargetPath {
    <#
    .SYNOPSIS
        解析「用户显式给出的清单参数」，失败时打印原因并返回空串。
    .DESCRIPTION
        bundle list / bundle edit 的 `<file>` 参数分支共用：只处理显式参数，未给参数时由调用方
        自己选清单（列表页与编辑页的选择方式不同）。错误文案在这一处统一，两页不会各写一份。
    .OUTPUTS
        [string] 成功时是清单绝对路径；参数不合法时为空串（原因已打印）
    #>
    param([hashtable]$Context, [string]$Path)

    $resolved = Resolve-WinstListPath -Context $Context -Text $Path
    if ($resolved.Ok) { return [string]$resolved.Path }

    Write-Host ''
    Write-Host ('  {0}' -f $resolved.Error) -ForegroundColor Red
    return ''
}
