# 命令行接口

```
winst [全局参数] <命令> [命令参数]
```

不带任何命令直接运行 `winst` 会进入交互式菜单。

## 全局参数

写在命令之前或之后都可以（`winst --pkg-dir D:\pkg list` 等价于 `winst list --pkg-dir D:\pkg`），也支持 `--pkg-dir=<路径>` 写法。`--pkg-dir`、`--install-root`、`--proxy` 必须带非空取值；行尾缺值、后接开关或使用等号空值均属于参数错误，以退出码 `1` 退出。

| 参数 | 说明 |
|---|---|
| `--pkg-dir <路径>` | 安装包位置（覆盖配置） |
| `--install-root <路径>` | 软件安装位置（覆盖配置） |
| `--proxy <地址>` | 代理地址，如 `http://127.0.0.1:7890` |
| `--offline` | 严格离线：不联网，只用已有缓存 |
| `--dry-run` | 只预览计划，不写盘、不执行安装或卸载；软件源解析仍可能联网 |
| `--yes` / `-y` | 非交互确认 |
| `--verbose` | 输出详细日志（HTTP、来源解析、文件匹配等） |

带值参数必须紧跟非空值；路径含空格时按 shell 规则加引号。配置优先级为命令行参数 > `WINST_INSTALL_ROOT` / `WINST_PKG_DIR` 环境变量 > `config.json` > 默认值；`pkgDir` 另有一个优先于配置文件的规则：脚本同目录存在 `apps\` 时自动使用该目录。

## 单进程限制

同一份数据目录（`WINST_HOME`，默认 `%USERPROFILE%\.winst`）**只允许一个 winst 运行**。已有实例时再次启动会打印占用者 PID 并以退出码 `1` 退出：

```
已经有一个 winst 正在运行，本次启动已退出。
正在运行的进程: PID 12345（启动于 2026-10-24T19:09:21）
```

原因：两个 winst 同时写 `state.json` / `winst.json` / `sources.json` 时，整份覆盖的写入方式会让先完成的那次改动丢失。

版本与帮助调用（`-v` / `--version` / `version`、`-h` / `--help` / `-?` / `help` / `?`）不抢锁；`WINST_NO_LOCK=1` 可手动跳过校验，但不应并发执行写操作。

锁本身打不开时（权限异常、只读卷等）本次启动**放行且不提示**，而不是判为「已有实例」；这种环境下并发写仍然会互相覆盖，只适合排障。

锁通过独占句柄实现，进程结束后由系统释放，不依赖删除锁文件。锁文件为 `<数据目录>\winst.lock`。

## 命令

| 命令 | 说明 |
|---|---|
| `winst search <关键字> [<关键字>...]` | 搜索全部软件源 |
| `winst info <id>` | 查看某个软件的详情 |
| `winst install <id> [<id>...]` | 安装 / 更新软件 |
| `winst download <id> [<id>...]` | 只下载软件包，不安装 |
| `winst list [--installed\|--cached]` | 列出已安装软件 / 已下载的安装包 |
| `winst update [选项] [<id>...\|--all]` | 检查 / 执行更新 |
| `winst uninstall <id> [<id>...]` | 卸载软件 |
| `winst clean [<id>]` | 清理安装包缓存 |
| `winst repair` | 扫描本机，重建安装台账 |
| `winst manifest add\|list\|update\|remove` | 管理在线软件源 |
| `winst bundle list\|edit\|install\|pack` | 安装清单与 U 盘套装 |
| `winst config get\|set\|list` | 配置管理 |
| `winst help [<命令>]` | 帮助 |
| `winst --version` / `-v` | 版本号 |

### search

```bat
winst search jdk
winst search jdk21 jdk25
```

匹配范围是 `id` / `name` / `description`，不区分大小写。多个关键字先用整串匹配，未命中再分别搜索并按 id 合并（OR）。

### info

```bat
winst info jdk21
```

显示各来源的可用版本、安装状态与位置、缓存状态与位置、条目类型与说明。

### install / download

```bat
winst install <id>... [--force] [--overwrite] [--keep a,b] [--kill]
                       [--files-only|--system-items] [--source <名称>] [--yes]
winst install winst --from <winst.zip|目录> [--force]
winst download <id>...
```

- 软件源里的版本比已装版本新 → **直接按更新安装**，不需要 `--force`
- 版本相同 → 提示已是最新，不动任何文件（除非有配套文件需要更新）
- 已装版本更高 → 拒绝降级，需 `--force`
- `--force`：强制安装 / 降级；`--overwrite`：绿色版重装时改用覆盖模式（不删旧目录）
- `--keep a,b`：临时指定清理模式下要保留的路径通配
- `--kill`：检测到目标程序在运行时直接结束进程
- `--files-only`：只替换文件，不写环境变量 / PATH；首次安装也不补这些系统项。已存在的快捷方式仍会校验并修正
- `--system-items`：完整处理系统项，覆盖 `updateFilesOnly` 配置；与 `--files-only` 同用时以 `--files-only` 为准（环境变量 / PATH 仍跳过）
- `--source <名称>`：优先使用指定软件源；该源没有目标条目时回退到默认来源并提示
- `--from <路径>`：仅从本地 zip 或解压目录安装 winst 自身，不查软件源、不解析依赖、不联网

带值选项也支持 `--source=<名称>`、`--keep=<通配>`、`--from=<路径>`。软件声明依赖时会先处理未安装或可更新的依赖。

`download` 与 `install` 对 `type: download` 条目等价：只解析来源、写入缓存，不解压、不安装、不写台账。

### list

```bat
winst list                :: 等价 --installed
winst list --cached
```

`--installed` 与 `--cached` 不能同时使用。

`--installed` 的每条记录里，若本机与记录版本并存着更低版本（见 `docs\data-files.md` 的 `oldVersions`），会多出一行「还并存旧版本 x」。清理入口只在菜单「已装软件」的详情页（`o)`），命令行不提供。

### update

```bat
winst update [--check] [--download-only] [--force]
             [--files-only|--system-items] [--source <名称>] [<id>...|--all]
```

- `--check`：只报告（有可更新项时退出码 4）；不能与 `--download-only` 同用
- `--download-only`：只刷新缓存，不安装
- `--all`：全部已登记软件；不能与 id 列表或 `--source` 同用
- 未带 `--all` 也未带 id 时，`update` 作用于台账里全部已登记软件

### uninstall

```bat
winst uninstall <id>... [--force] [--kill] [--yes]
```

- `--force`：找不到卸载程序时只移除登记；也用于跳过卸载命令
- `--kill`：检测到运行中的进程时直接结束；非交互执行不加此开关时会报错
- 非 winst 安装（`external`）若有卸载定义，按其定义卸载；没有卸载定义时只移除登记，不删除用户自行安装的程序文件
- `type: download` 没有安装记录，删除缓存请用 `winst clean <id>`

### clean

```bat
winst clean          :: 清理各软件的旧版本安装包
winst clean <id>     :: 删除该 id 的全部已下载安装包
```

### repair

```bat
winst repair
```

扫描安装根目录、注册表卸载项与 Appx 记录，重建 / 校对 `state.json`，并在需要时校对缓存索引 `winst.json`。不删除软件文件，不修改环境变量、PATH 或快捷方式；目录缺失的台账条目只报告、不删除。

### manifest

```bat
winst manifest add <仓库|地址>    :: 支持 用户名/仓库、仓库页地址、清单 raw 地址
winst manifest list
winst manifest update [<名称>|--all]
winst manifest remove <名称>
```

只支持 GitHub 仓库源；添加时会实际拉取并校验清单。内置源 `dsx42/winst-manifest` 与本地源 `local` 不能被添加或删除。`update` 不带名称或带 `--all` 时刷新全部源；不能与 `--offline` 同用。

### bundle

```bat
winst bundle list [<file>]
winst bundle edit [<file>]
winst bundle install [<file>] [--skip-existing]
winst bundle pack <清单> <目标目录> [--skip-missing]
```

不带文件参数时默认使用 `<数据目录>\lists\setup.list`。文件名按该目录解析并自动补 `.list` 后缀；显式路径也必须位于此目录内。

- `bundle list` 不带文件时列出全部清单，带文件时显示内容与状态
- `bundle edit` 进入交互式编辑
- `bundle install --skip-existing` 跳过已登记的条目（任意版本），并非只跳过同版本
- `bundle pack` 收集清单软件及引擎的安装包、脚本、软件源数据与清单，生成离线套装；`--skip-missing` 缺包时不联网补齐，直接跳过对应软件

### config

```bat
winst config list
winst config get <key>
winst config set <key> <value>
```

不带子命令等价于 `config list`。`set` 会校验并转换布尔、数字等配置值，写入 `<数据目录>\config.json`。配置项见 [data-files.md](data-files.md#configjson)。

## 退出码

| 码 | 含义 |
|---|---|
| `0` | 成功 / 用户取消 / 菜单正常返回 |
| `1` | 参数错误、找不到目标、内部错误、已有一个 winst 正在运行 |
| `2` | 网络失败 |
| `3` | 安装 / 卸载 / 校验失败 |
| `4` | `update --check` 检测到可更新项（未执行更新） |

## 交互菜单

不带参数运行进入主菜单：

```
 1) 安装软件        搜索并安装，支持一次装多个
 2) 检查更新        检查有没有新版本，并帮你更新
 3) 卸载软件        从电脑上移除已安装的软件
 4) 已装软件        查看已安装的软件，可更新/卸载
 5) 已下载包        查看下载好的安装包，可安装/更新/删除
 6) 软件列表        软件源里的全部软件，可安装/更新/卸载/删除安装包
 7) 一键安装        按安装清单批量安装（重装系统后使用）
 8) 高级功能        软件源、安装清单、U盘安装包
 0) 设置            安装位置、安装包位置、代理等
 q) 退出
```

- 高级功能：1 管理软件源、2 管理安装清单、3 制作 U 盘安装包
- 「已装软件」详情：`u` 按设置的更新方式更新、`c` 单独选更新方式与来源、`o` 清理本机并存的旧版本（只有检测到多个版本时才出现）、`d` 卸载、`r` 重新检测版本
- 「检查更新」是一个结果页循环：选中编号更新完后**回到同一张结果页**，只列出剩下还能更新的软件，可以接着更新；`u` 全部更新、回车 / `b` 返回。上一轮的成功 / 失败条数会打一行，失败的条目留在列表里可重试
- 管理软件源：编号进入详情，`r` 刷新、`d` 删除（内置源与本地清单不可删）；直接输入 GitHub 仓库或清单地址可添加，`c` 从剪贴板读取地址，`a` 刷新全部
- 管理安装清单：编号查看后可编辑或删除；直接输入文件名可新建或编辑
- 设置：安装位置、安装包位置、代理、代理模式、下载后清理旧包、软件源刷新间隔、更新方式
- 列表类页面支持多选（`1 3 5`），`b` 返回，`q` 退出；输入关键字可过滤
- 菜单与命令行执行同一套业务逻辑，不存在只有菜单才能做的事