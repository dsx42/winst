#Requires -Version 5.1

function Show-BundleCliHelp {
    <#
    .SYNOPSIS:
        CLI `winst bundle` 的用法说明（无子命令 / help 时输出）。
    #>
    Write-Host ''
    Write-Host '  用法: winst bundle <list|edit|install|pack> [参数]' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '    list [<file>]                          列出全部安装清单；指定文件显示内容与各项状态' -ForegroundColor Gray
    Write-Host '    edit [<file>]                          编辑安装清单（从软件源挑选，可多选）' -ForegroundColor Gray
    Write-Host '    install [<file>] [--skip-existing]     按安装清单逐个安装（缺省 lists\setup.list）' -ForegroundColor Gray
    Write-Host '    pack <安装清单> <目标目录> [--skip-missing]' -ForegroundColor Gray
    Write-Host '                                           收集安装包 + 脚本 + 清单，生成 U 盘离线套件' -ForegroundColor Gray
    Write-Host ''
    Write-Host '  通用参数: --offline / --dry-run / --yes / --verbose' -ForegroundColor DarkGray
    Write-Host '  说明: 新建安装清单用 `winst bundle edit`，直接从软件源挑选。' -ForegroundColor DarkGray
}
