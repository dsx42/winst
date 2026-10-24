#Requires -Version 5.1

function Show-ManifestCliHelp {
    <#
    .SYNOPSIS:
        CLI `winst manifest` 的用法说明。
    #>
    Write-Host ''
    Write-Host '  用法: winst manifest <add|list|update|remove>' -ForegroundColor Yellow
    Write-Host '    manifest add <仓库|地址>          添加 GitHub 仓库软件源（名称自动取 用户名/仓库）' -ForegroundColor Gray
    Write-Host '    manifest list                    列出全部软件源（含本地清单）' -ForegroundColor Gray
    Write-Host '    manifest update [<名称>|--all]    刷新软件源（本地清单也走同样流程）' -ForegroundColor Gray
    Write-Host '    manifest remove <名称>            删除软件源' -ForegroundColor Gray
    Write-Host '  示例: winst manifest add owner/repo' -ForegroundColor DarkGray
    Write-Host '  提示: 把清单文件放在脚本同目录（manifest.json 或 manifests\*.json）即作为本地清单自动生效，无需添加。' -ForegroundColor DarkGray
}
