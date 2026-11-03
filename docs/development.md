# 开发与发布

## 运行与隔离

目标运行时为 Windows PowerShell 5.1。开发树从 `Modules/Winst.*` 导入，release 从合并的 `Modules/Winst` 导入；无需安装模块或配置 PSModulePath。模块职责和约束见 [架构](architecture.md) 与仓库 [AGENTS.md](../AGENTS.md)。

```powershell
$env:WINST_HOME = Join-Path $env:TEMP 'winst-dev/home'
$env:WINST_INSTALL_ROOT = Join-Path $env:TEMP 'winst-dev/root'
$env:WINST_PKG_DIR = Join-Path $env:TEMP 'winst-dev/pkg'
$env:WINST_NO_ELEVATE = '1'
powershell -NoProfile -ExecutionPolicy Bypass -File .\winst.ps1 -v
powershell -NoProfile -ExecutionPolicy Bypass -File .\winst.ps1 config list
```

实验目录应为本次独立目录。安装、更新、卸载和修复会修改台账及系统项，不能直接用真实用户数据验证删除分支。网络请求可通过 `--offline` 禁止，预览边界见 [CLI](cli.md#预览边界)。

根目录 `manifest.json` 是不跟踪的本地测试副本；正式软件源由独立的 `dsx42/winst-manifest` 仓库维护。构建会把本地副本复制到 `dist/winst`，但不放进 zip。不要把本地测试改动作为正式源发布。

## 调试与模块扩展

- `WINST_DEV=1` 强制重新导入开发模块；`--verbose` 输出诊断。
- 导入单个模块时用清单绝对路径；跨模块依赖由调用环境导入，详见各 psd1 注释，不使用 RequiredModules。
- 新模块目录与 psd1/psm1 同名，包含 Public；加载器与其它模块保持一致。
- 新函数放 Public 或 Private，加载器自动发现；跨模块调用只用 Public。只定义函数的约束有 `WinstState.Type.ps1` 加载 .NET 状态/捕获类型这一明确例外。
- 新状态项在 Initialize-WinstState 声明；写入遵循 [数据文件](data-files.md) 的条目级提交与缓存失效契约。
- 新清单字段或枚举必须同步 [清单规范](manifest.md)，示例要能通过真实读取和解析函数。

### 环境变量

| 变量 | 作用 |
|---|---|
| WINST_HOME | 配置及安装清单数据根目录 |
| WINST_INSTALL_ROOT | 软件安装根及 state.json 所在位置 |
| WINST_PKG_DIR | 包缓存、软件源列表和解析数据位置 |
| WINST_DEV | 为1时强制重新导入模块 |
| WINST_NO_ELEVATE | 为1时不自动提权，适用于隔离验证或排障 |
| WINST_NO_LOCK | 为1时跳过单进程锁；仅排障用，不能据此并发修改数据 |
| CI | 为1时构建不等待回车 |

## 文件格式

| 文件 | 编码与换行 |
|---|---|
| ps1/psm1/psd1 | UTF-8 BOM + CRLF |
| install.ps1 | UTF-8无BOM + CRLF；不写 #Requires |
| build.cmd、winst.cmd | GBK + CRLF |
| Markdown、测试清单 | UTF-8无BOM |
| winst写出的JSON和list | UTF-8无BOM |

构建检查 Modules 下脚本、winst.ps1、build.ps1 的 BOM/CRLF，并单独检查 install.ps1；批处理 GBK 需要编辑器和人工保证。构建不修复源文件格式。显式写脚本使用 UTF8Encoding(true)，写数据使用 UTF8Encoding(false)。

## 验证

在 Windows PowerShell 5.1 中执行模块语法检查，再执行上面的隔离入口：

```powershell
Get-ChildItem Modules -Recurse -File |
    Where-Object Extension -in '.ps1','.psm1','.psd1' |
    ForEach-Object {
        $e=$null
        [void][Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$null,[ref]$e)
        if($e){ "$($_.FullName): $($e[0].Message)" }
    }
```

`Tests/*.Regression.ps1` 是无需测试框架的断言脚本，各自在独立的 Windows PowerShell 5.1 进程运行：

```powershell
Get-ChildItem Tests -Filter *.Regression.ps1 | ForEach-Object {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $_.FullName
    if ($LASTEXITCODE -ne 0) { throw ('回归失败：{0}' -f $_.Name) }
}
```

针对实际改动验证成功、失败、取消和退出码。持久化字段要验证保存后重启读取；缓存要覆盖冷/热及写入失败；路径安全用自建临时目录和链接；环境变量、凭据、安装器用桩或隔离系统，不能改真实设置。回归脚本覆盖缓存校验、来源解析、安装生命周期和菜单分支，不能替代真实系统集成验证。

## 构建

```powershell
$env:CI='1'
cmd /c build.cmd
```

交互构建可直接双击 build.cmd；`-NoPause` 与 CI=1 均跳过等待。build.cmd 负责切目录、透传参数和退出码，逻辑在 build.ps1。

构建自动发现模块并检查目录、加载器、编码、函数重名和合并语法；随后在临时发布树运行 `winst.ps1 -v`，核对版本、zip必需/禁止条目及顶层布局，最后生成：

- `dist/winst/`：可直接运行的发布树。
- `dist/winst.zip`：运行时文件，没有文档、构建工具、引导脚本及测试清单。
- `dist/winst.zip.sha512`：sha512sums格式的摘要侧车。

构建开始会清空 dist；失败时不能将其中未完成的内容作为发布包。构建冒烟验证装配，不代替安装/卸载或具体缺陷回归。

## 发布

1. 修改唯一产品版本来源：Core/Public/WinstConstants.ps1 的 Get-WinstProductVersion。
2. 完成验证和构建，tag 使用 `v<产品版本>`。
3. 上传同次生成的 winst.zip 与 winst.zip.sha512，资产名不带版本。

正式清单的 `_manifestVersion` 独立于产品版本，仅在软件源仓库修改清单时维护。

`install.ps1` 通过 `irm | iex` 下载并解压 release，再调用 `winst install winst --from <zip>`。安装逻辑集中在 Install-WinstSelf；引导层负责提权、等待、退出码、临时目录清理和恢复调用者偏好，不使用 exit、PSScriptRoot 或本地模块依赖。
