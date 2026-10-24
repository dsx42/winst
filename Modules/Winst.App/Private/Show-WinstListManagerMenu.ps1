#Requires -Version 5.1

function Show-WinstListManagerMenu {
    <#
    .SYNOPSIS
        渲染「高级功能 → 管理安装清单」：直接列出 lists 目录里的全部安装清单（与「管理软件源」同一形态）。
    .DESCRIPTION
        没有单独的「查看」菜单项：输入编号即查看（随后可选编辑 / 删除），输入文件名即新建
        （已存在则进入编辑）。
    .OUTPUTS
        @( [ordered]@{ Name; Path; Count; Modified } )——与列表编号一一对应
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context
    )

    $kindText = (Get-WinstListKindText)
    $defaultName = (Get-WinstListFileName)

    Show-Banner -Context $Context
    Write-Host ''
    Write-Host ('  高级功能 · 管理{0}' -f $kindText) -ForegroundColor Cyan
    Write-Host '  安装清单 = 重装系统后要装的软件列表（供「一键安装」与「制作U盘安装包」使用）。' -ForegroundColor DarkGray
    Write-Host ''

    $files = @(Get-WinstListFiles -Context $Context)
    $defaultMark = '    ← 默认（一键安装）'
    if ($files.Count -eq 0) {
        Write-Host ('  （lists 目录里还没有{0}）' -f $kindText) -ForegroundColor DarkGray
    } else {
        for ($i = 0; $i -lt $files.Count; $i++) {
            $file = $files[$i]
            $when = ''
            if ($file['Modified']) {
                try { $when = ([datetime]$file['Modified']).ToString('yyyy-MM-dd HH:mm') } catch { $when = '' }
            }
            $mark = ''
            if ([string]$file['Name'] -ieq $defaultName) { $mark = $defaultMark }
            Write-Host ('    {0}) {1}    {2} 项    {3}{4}' -f ($i + 1), [string]$file['Name'], [int]$file['Count'], $when, $mark) -ForegroundColor White
        }
    }

    Write-Host ''
    Write-Host ('  清单目录: {0}' -f (Get-WinstListsDir -Context $Context)) -ForegroundColor DarkGray
    Write-Host '  输入编号 = 查看 / 编辑 / 删除这份清单' -ForegroundColor DarkGray
    Write-Host '  输入文件名 = 新建清单（自动补 .list，如 work.list）' -ForegroundColor DarkGray
    Write-Host '  回车 / b = 返回，q = 退出程序' -ForegroundColor DarkGray
    Write-Host ''

    return @($files)
}
