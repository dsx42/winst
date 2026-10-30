#Requires -Version 5.1

function Show-WinstHelp {
    <#
    .SYNOPSIS
        CLI 总帮助：`winst help` 输出全部命令；`winst help <命令>` 输出该命令的用法。
    #>
    param([string]$Command = '')

    $name = ''
    if ($null -ne $Command) { $name = ([string]$Command).Trim().ToLowerInvariant() }

    if ($name) {
        Write-Host ''
        switch ($name) {
            'search'    {
                Write-Host '  用法: winst search <关键字> [<关键字>...]' -ForegroundColor Yellow
                Write-Host '    搜索全部软件源（本地清单 + 内置源 + 用户添加的仓库源）；多个关键字整串优先，未命中再分别搜索合并。' -ForegroundColor Gray
            }
            'info'      {
                Write-Host '  用法: winst info <id> [--force]' -ForegroundColor Yellow
                Write-Host '    查看某个软件的详情（各来源版本、安装状态与位置、下载状态与位置、类型与说明）。' -ForegroundColor Gray
                Write-Host '    --force: 忽略版本信息有效期，重新解析这个软件（调试本地清单时用）。' -ForegroundColor Gray
            }
            'download'  {
                Write-Host '  用法: winst download <id> [<id>...]' -ForegroundColor Yellow
                Write-Host '    只把软件包下载到安装包位置，不安装到电脑（「仅下载」类型用它下载 / 更新软件包）。' -ForegroundColor Gray
            }
            'install'   {
                Write-Host '  用法: winst install <id> [<id>...] [--force] [--overwrite] [--keep a,b] [--source <名称>] [--kill]' -ForegroundColor Yellow
                Write-Host '        [--files-only|--system-items] [--yes]   安装 / 更新软件（软件源里是更新版本时直接按更新安装，无需 --force）' -ForegroundColor Gray
                Write-Host '  用法: winst install winst --from <winst.zip|目录> [--force]' -ForegroundColor Yellow
                Write-Host '    从本地安装包安装 winst 自身（版本相同则跳过，更新则替换文件并保留 lists\）；不走软件源、不联网。' -ForegroundColor Gray
            }
            'list'      {
                Write-Host '  用法: winst list [--installed|--cached]' -ForegroundColor Yellow
                Write-Host '    --installed（缺省）列出已安装的软件；--cached 列出已下载的安装包。' -ForegroundColor Gray
            }
            'update'    {
                Write-Host '  用法: winst update [--check] [--download-only] [--force] [--files-only|--system-items] [--source <名称>] [<id>...|--all]' -ForegroundColor Yellow
                Write-Host '    检查 / 执行更新；--check 只报告（有可更新项时退出码 4）。' -ForegroundColor Gray
            }
            'uninstall' {
                Write-Host '  用法: winst uninstall <id> [<id>...] [--force] [--kill] [--yes]' -ForegroundColor Yellow
                Write-Host '    卸载软件；非 winst 安装（仅登记）有卸载定义时按定义卸载、没有时只移除登记；--force 跳过卸载命令（卸载器缺失时也用它只移除登记）；--kill 自动结束正在运行的进程。' -ForegroundColor Gray
            }
            'clean'     {
                Write-Host '  用法: winst clean [<id>]' -ForegroundColor Yellow
                Write-Host '    无参数 = 清理各软件的旧版本安装包；指定 id = 删除该 id 的全部已下载安装包。' -ForegroundColor Gray
            }
            'repair'    {
                Write-Host '  用法: winst repair' -ForegroundColor Yellow
                Write-Host '    扫描本机，按软件源里的定义重建 / 校对安装记录（只写 state.json，不动任何文件与系统项）。' -ForegroundColor Gray
            }
            'manifest'  { Show-ManifestCliHelp }
            'bundle'    { Show-BundleCliHelp }
            'config'    {
                Write-Host '  用法: winst config get|set|list [<key> [<value>]]' -ForegroundColor Yellow
                Write-Host '    list 列出全部配置项、当前值与来源；get 读某一项；set 写某一项。' -ForegroundColor Gray
            }
            default     {
                Write-Host ('  没有「{0}」这个命令。' -f $name) -ForegroundColor Yellow
                Write-Host '  用 winst help 查看全部命令。' -ForegroundColor Gray
                return 1
            }
        }
        return 0
    }

    Write-Host ''
    Write-Host ('  winst {0}  ·  Windows 软件安装与管理' -f (Get-WinstProductVersion)) -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  用法: winst [全局参数] <命令> [命令参数]' -ForegroundColor Gray
    Write-Host '  不带命令直接运行 winst 会进入交互式菜单。' -ForegroundColor Gray
    Write-Host ''
    Write-Host '  命令:' -ForegroundColor White
    Write-Host '    search <关键字>            搜索软件' -ForegroundColor Gray
    Write-Host '    info <id>                  查看某个软件的详情' -ForegroundColor Gray
    Write-Host '    install <id>...            安装 / 更新软件' -ForegroundColor Gray
    Write-Host '    download <id>...           只下载软件包，不安装' -ForegroundColor Gray
    Write-Host '    list [--installed|--cached]  列出已安装软件 / 已下载的安装包' -ForegroundColor Gray
    Write-Host '    update [--check|--all|...]  检查 / 执行更新' -ForegroundColor Gray
    Write-Host '    uninstall <id>...          卸载软件' -ForegroundColor Gray
    Write-Host '    clean [<id>]               清理安装包缓存' -ForegroundColor Gray
    Write-Host '    repair                     修复安装记录' -ForegroundColor Gray
    Write-Host '    manifest add|list|update|remove   管理软件源' -ForegroundColor Gray
    Write-Host '    bundle list|edit|install|pack     安装清单' -ForegroundColor Gray
    Write-Host '    config get|set|list        配置管理' -ForegroundColor Gray
    Write-Host '    help [<命令>]              显示帮助' -ForegroundColor Gray
    Write-Host '    --version | -v             显示版本号' -ForegroundColor Gray
    Write-Host ''
    Write-Host '  全局参数（写在命令之前）:' -ForegroundColor White
    Write-Host '    --pkg-dir <路径>           安装包位置' -ForegroundColor Gray
    Write-Host '    --install-root <路径>      软件安装位置' -ForegroundColor Gray
    Write-Host '    --proxy <地址>             代理地址' -ForegroundColor Gray
    Write-Host '    --offline                  严格离线（不联网，只用已有缓存）' -ForegroundColor Gray
    Write-Host '    --dry-run                  预览操作，仍可能联网或写入元数据' -ForegroundColor Gray
    Write-Host '    --yes | -y                 非交互确认' -ForegroundColor Gray
    Write-Host '    --verbose                  输出详细日志' -ForegroundColor Gray
    return 0
}
