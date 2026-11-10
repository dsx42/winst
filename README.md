# winst

Windows 软件包管理器（Windows PowerShell 5.1）：下载、安装、更新、卸载、批量部署，绿色免安装。

覆盖三种场景：联网安装、离线重装（U 盘套装）、局域网共享安装包（NAS 统一缓存）。

## 特性

- **一条命令安装**：下载最新 release 并安装 winst 自身；下载、解压引擎在首次需要时自动安装
- **软件源与数据分离**：脚本只含逻辑，软件定义全在清单里（内置源、自定义 GitHub 源、本地清单）
- **离线优先**：取包前先查本地缓存，未命中且允许联网才下载
- **多种下载来源**：固定直链、GitHub Releases、版本列表页、详情页、JSON 接口、XML 接口、磁力链接
- **多种条目类型**：绿色版（解压）、安装版（静默安装）、单文件、仅下载
- **识别已有安装**：检测并登记外部软件；更新和卸载的具体动作按实际计划确认，见 [CLI](docs/cli.md#uninstall)
- **可修复的台账**：`state.json` 损坏或丢失可扫描重建；批量操作单条失败不影响其余

## 环境要求

- Windows 10 / 11，x64
- Windows PowerShell 5.1（系统自带，不依赖 pwsh 或任何外部 PowerShell 模块）
- 两个外部引擎由 winst 自己管理，无需预装：`FluxDown-CLI`（下载包）、`7-Zip-CLI`（解压）

## 安装

### 一行命令（推荐）

```powershell
irm https://raw.githubusercontent.com/dsx42/winst/main/install.ps1 | iex
```

装到 `%USERPROFILE%\winst\winst\`，并创建桌面 / 开始菜单快捷方式。想先看内容：

```powershell
irm https://raw.githubusercontent.com/dsx42/winst/main/install.ps1 | more
```

### 手动安装

从 [Releases](https://github.com/dsx42/winst/releases) 下载 `winst.zip`，解压到任意目录，双击 `winst.cmd` 即可运行（不写 PATH、不改注册表）。

### 从本地安装包安装（离线）

```bat
winst install winst --from D:\downloads\winst.zip
winst install winst --from D:\downloads\winst
```

`--from` 接受 release 压缩包或解压后的目录，不查软件源、不解析依赖、不联网。可加 `--install-root` 指定安装根目录；一行安装脚本也使用这种方式。

### 升级与卸载

- **升级**：重跑一行安装命令，或 `winst update winst`
- 同版本跳过；release 版本更低时拒绝降级，确需降级加 `--force`
- 升级保留安装目录中的 `lists\` 与 `*.list`
- **卸载**：`winst uninstall winst`（删除安装目录与 winst 创建的系统项，数据目录保留）

## 快速上手

```bat
winst                              :: 无参数进入交互式菜单
winst search jdk                   :: 搜索软件
winst info jdk21                   :: 查看详情（各源版本、安装状态、缓存状态）
winst install vscode python3       :: 安装（已有更新版本时自动按更新处理）
winst list                         :: 已安装软件（等价 list --installed）
winst list --cached                :: 已下载的安装包
winst update --check               :: 只检查更新（有可更新项时退出码 4）
winst update --all                 :: 全部更新
winst uninstall Rufus              :: 卸载（id 区分大小写）
winst clean                        :: 清理旧版本安装包
winst repair                       :: 扫描本机，重建安装台账
winst bundle install setup.list    :: 按安装清单批量安装
winst bundle pack setup.list E:\   :: 制作 U 盘离线套装
winst config list                  :: 查看配置项
winst help                         :: 全部命令
```

全局参数（写在命令前后都行）：`--pkg-dir`、`--install-root`、`--proxy`、`--offline`、`--dry-run`、`--yes` / `-y`、`--verbose`。完整命令与选项见 [docs/cli.md](docs/cli.md)。

## 配置

`winst config list` 查看，`winst config set <key> <value>` 写入 `%USERPROFILE%\.winst\config.json`：

配置项的默认值和完整说明见 [数据文件：config.json](docs/data-files.md#configjson)。代理模式支持 `auto`、`always`、`off`、`download-direct`；清除 winst 显式代理使用 `winst config reset proxy`，设置菜单也可输入 `-` 清除。

HTTP 默认请求继承系统代理与 PAC；`off` 只禁用 winst 配置的显式代理，不强制绕过系统代理。

命令行参数优先于同名配置；目录还可用环境变量 `WINST_INSTALL_ROOT`、`WINST_PKG_DIR` 覆盖。软件源列表和清单位于实际使用的 `pkgDir\manifests\` 下，更换缓存目录时需注意。

## 数据位置

```
%USERPROFILE%\.winst\            数据目录（WINST_HOME 覆盖）
├── config.json                  用户配置
├── lists\setup.list             默认安装清单
└── apps\                        安装包缓存（pkgDir 默认值）
    ├── winst.json               缓存索引
    ├── <id>\                    各软件的安装包
    └── manifests\               软件源列表、源缓存、本地清单

<installRoot>\                   安装根目录（默认 %USERPROFILE%\winst）
├── state.json                   安装台账
├── winst\                       winst 自身
└── <id>\                        各软件安装目录
```

脚本同目录存在 `apps\` 时优先用作 `pkgDir`，其优先级高于配置文件。本地清单还可放在脚本同目录的 `manifest.json` 或 `manifests\*.json`，无需添加软件源。

数据文件格式见 [docs/data-files.md](docs/data-files.md)。

## 文档

- [docs/README.md](docs/README.md) — 文档索引
- [docs/architecture.md](docs/architecture.md) — 模块划分、依赖关系、代码约定
- [docs/cli.md](docs/cli.md) — 命令行接口、退出码
- [docs/manifest.md](docs/manifest.md) — 软件源与清单条目 schema
- [docs/data-files.md](docs/data-files.md) — config / state / 缓存索引 / 清单文件
- [docs/install-flows.md](docs/install-flows.md) — 安装、更新、卸载、修复流程与版本检测
- [docs/development.md](docs/development.md) — 开发与打包发布
- [docs/troubleshooting.md](docs/troubleshooting.md) — 常见问题

## 开发与发布

```bat
build.cmd
```

构建输出 `dist\winst\`、`dist\winst.zip` 和 `dist\winst.zip.sha512`。发布 zip 包含 `winst.ps1`、`winst.cmd`、`LICENSE` 与合并后的 `Modules\Winst\`；版本号定义在 `Get-WinstProductVersion`。开发约定与发布步骤见 [docs/development.md](docs/development.md)。
