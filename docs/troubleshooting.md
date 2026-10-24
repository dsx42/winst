# 常见问题与排查

## 先看这几条

```bat
winst --version                  :: 版本是否最新
winst config list                :: 实际生效的配置
winst info <id>                  :: 这个软件各源版本、安装状态、缓存状态
winst repair --dry-run           :: 台账是否与实际不一致（不写盘）
winst --verbose list             :: 详细日志
```

`--dry-run` 不下载、不安装、不写台账或缓存索引；软件源查询仍可能联网，需要完全离线时同时加 `--offline`。winst 自身安装的预览会明确拒绝执行。

## 安装与更新

### 「已安装 x，但软件源里没有可用版本」

条目声明了 `source.versionFrom: "package"`（版本要等包下载后才知道），或源侧确实没给出可比较的版本。加 `--force` 强制安装 / 更新。

### 「已安装 x，软件源是 y，需要 --force 才能降级」

源侧版本比本机低。确认要继续降级就加 `--force`。

### 版本相同但又要装一次

同版本默认跳过、不动任何文件。要强制重装：`winst install <id> --force`。

### 下载很慢 / 失败

```bat
winst install <id> --proxy http://127.0.0.1:7890
winst config set proxyMode always      :: 一直走代理
winst config set proxy http://127.0.0.1:7890
```

- 代理只影响 winst 自己的请求；软件包下载由 FluxDown 执行，`--proxy` 会传给下载器
- 下次下载前会清理本目标的 `.fdownloading` 与 `名称 (N).zip` 残留；失败后可重试
- 部分站点对自动化请求返回 403，清单里对应条目会用 `fetchWith: "browser"`（系统自带 Edge 无头抓取）

### 解压失败

解压首选 `7-Zip-CLI`，它不可用时依次退到系统自带 `tar.exe` 与 `Expand-Archive`（仅 zip），**不会**去用目标机上安装的完整版 7-Zip：

```bat
winst install 7-Zip-CLI --force
```

失败时 `--verbose` 会带出 7z 的原始错误，可据此判断是包损坏还是格式不支持。

### 「请以管理员身份运行 winst」

安装目录不在 `%USERPROFILE%` 之下时，`env` / `addToPath` 要写入系统级（Machine），需要管理员权限。两种选择：

- 用管理员身份重开终端再执行
- 把 `installRoot` 指到用户目录下（默认位置就不需要提权）

### 目标程序正在运行，无法继续

```bat
winst install <id> --kill      :: 自动结束
winst uninstall <id> --kill
```

不自动结束时，交互模式会列出进程并提供 `k`（结束）/ `c`（手动关闭后继续）选项。

## 卸载

### 「没有安装记录，无法卸载」

`download` 类型条目从不写台账。要清理它的缓存：`winst clean <id>`。

### 「非 winst 安装，只移除登记」

`managed: "external"` 的条目默认只删台账记录，不动文件；清单或台账里已有卸载定义的除外。要对默认只登记的条目实际执行卸载，加 `--force`。

### 卸载后程序文件还在

卸载程序可能已执行成功但需要重启，或卸载器没有清干净；安装目录残留默认会保留并列出路径。先重启再检查，仍残留时手动删除安装目录。若只是卸载命令失败且软件已手动移除，可加 `--force` 只移除登记；不要指望这个开关清理已经留下的文件。

## 台账与缓存

### 安装记录看起来不对

```bat
winst repair --dry-run     :: 先看会改什么，不写台账或缓存索引
winst repair               :: 校对 state.json，必要时重建缓存索引
```

`repair` 扫描安装根目录、注册表卸载项、Appx 记录重建台账，并校对 `<pkgDir>\winst.json`。它不修改软件文件、环境变量或快捷方式；缓存索引损坏时先备份为 `winst.json.bak`，再按目录内实际文件重建。

### `state.json` 损坏

winst 会自动把它备份为 `state.json.bak-<时间戳>` 并重建，随后 `winst repair` 可把已装软件扫回来。

### 改了 `installRoot` 之后列表空了

台账跟着安装位置走：新位置没有 `state.json`，进入「已装软件」会自动扫描一次，或手动 `winst repair`。

### 缓存列表与实际文件不一致

`winst list --cached` 只列出 `<pkgDir>\<id>` 下实际含文件的目录；空目录不算有缓存。索引指向已删除目录的条目会被剔除，索引缺失或损坏时可运行 `winst repair` 重建。目标包文件确实缺失或校验失败时需要重新下载。

### NAS / U 盘路径

`pkgDir` 可以直接指向 UNC 路径：

```bat
winst config set pkgDir \\NAS\winst\apps
```

- 多台机器共用时，安装包、源列表、清单缓存都共享；一台机器下载后，其余机器可复用这些文件
- 索引文件通过「临时文件 + 替换」写入，降低写到一半损坏的风险；多机并发没有跨机器互斥，后完成者会覆盖整份索引
- 目标机看不到 NAS 时只会影响新的下载，已装软件不受影响

## 软件源

### 「软件源里没有这个软件」

```bat
winst manifest list
winst manifest update --all
winst search <关键字>
```

本地清单也要参与：把 `manifest.json` 放在脚本同目录、或 `<pkgDir>\manifests\*.json`，自动识别为 `local` 源。

### 源刷新失败

- `--offline` 下不刷新，只用已有缓存与本机清单；`manifest update --offline` 会直接报参数错误
- 单个源失败不影响其它源，刷新汇总会给出成功 / 失败数；网络失败返回 `2`，其它刷新失败返回 `1`
- 条目级失败（地址 404、页面结构变了、字段缺失）不会让其它条目失败。`manifest update` 逐条显示「有误」并在末尾列原因；若该条目有上次成功结果，会保留旧结果并注明本次失败原因
- `manifest list` 只显示各来源与清单概况；要看条目错误，执行 `winst manifest update <名称>`

### 内置源 `dsx42/winst-manifest` 改不了 / 删不掉

设计如此：它是内置源，缺失会被补回、地址被改会被纠正、不能删除。要自定义某个软件，在本地清单里写同 id 的条目即可，两个源并存、安装时可选。

## 页面型来源（page / listing / json）

### 「全部候选都不可用」

`listing` 源会从高到低探测候选地址（上限 8 个）。列表页里混入的噪声数字占满名额时就会这样。改用能直接给出真实版本的来源：`page`（带版本号的下载直链）或 `json` 接口。

### 「页面提取不到下载链接」

站点改版。排查顺序：

1. `--verbose` 看候选链接列表
2. 调整清单里 `link` 的 `class` / `id` / `text` / `href`
3. 地址由点击生成时改用 `source.click` + `fetchWith: "browser"`
4. 命中的是中转页时改用 `source.thenLink`（再抓一层）或 `thenClick`（浏览器里再点一次）

### 下载地址过期（403 / 404）

签名地址通常 1 小时左右失效。winst 在下载失败时会自动重新解析来源取新地址并重试一次。

## 快捷方式与环境变量

### 快捷方式双击打不开 `.ps1`

`.lnk` 指向 `.ps1` 时双击只会打开编辑器。winst 创建快捷方式时会在脚本旁生成同名 `.cmd` 启动器，并让快捷方式指向它；启动器生成失败时会明确提示并跳过快捷方式。`winst` 自身也是 `winst.ps1` + `winst.cmd`。

### PATH 里出现重复项

winst 写入前会按原始文本比对（不区分大小写，已有项忽略首尾空白和包围引号），已存在就不重复追加。它不会合并 `%VAR%` 与实际路径等价的不同写法，也不会清理既有重复项；重复项需手动处理。卸载只会回收台账登记为本次写入的 PATH 项，不会借此清掉原有重复项。

### 环境变量里写的是 `%JAVA_HOME%\bin` 而不是真实路径

正常。`%VAR%` 会原样写入（`REG_EXPAND_SZ`），这样切换 `JAVA_HOME` 时 PATH 会自动跟随。`{installDir}` 与 `{installRoot}` 则展开为本机实际路径。

### 卸载后环境变量没了

winst 只回收台账里登记为「它自己写入」的项。手动配置的同值项不会被登记，也就不会被删除；winst 写入的项会被移除。若另一份已装软件仍声明同名变量，卸载会恢复为那份软件需要的值；仍被其它软件使用的 PATH 项则保留。winst 不保存安装前的原始值，需要保留时请在卸载前手动记录。

### Windows Terminal 里变量显示未展开

`REG_EXPAND_SZ` 的 `%VAR%` 在 Windows Terminal 里存在已知不展开问题（microsoft/terminal#9741），不是 winst 的问题。需要固定值就直接写实际路径。

## 交互菜单

### 菜单里粘贴路径没反应

「安装软件」的关键字输入会识别盘符、`\` / `/` / `.\` / `..\`、含反斜杠的路径，以及以 `.exe` / `.cmd` / `.bat` / `.ps1` / `.lnk` / `.msi` 结尾的命令行，提示这不是软件名称并重新输入；不会把这些路径当关键字搜索。

### 中文乱码

- 脚本文件被改成了无 BOM 的 UTF-8（Windows PowerShell 5.1 会按 ANSI 读），重新保存为 UTF-8 with BOM
- 控制台代码页不对：`chcp 65001` 或 `chcp 936` 后再试
- `build.cmd` 必须是 GBK，被改成 UTF-8 后批处理里的注释与提示会乱码

## 退出码

| 码 | 含义 | 常见原因 |
|---|---|---|
| `0` | 成功 / 取消 / 菜单正常返回 | |
| `1` | 参数错误、找不到目标、内部错误、单进程锁被占用 | 命令拼错、id 不存在、清单非法、已有另一个 winst 在运行 |
| `2` | 网络失败 | 代理不通、目标站不可达 |
| `3` | 安装 / 卸载 / 校验失败 | 校验不匹配、解压失败、卸载命令非零退出 |
| `4` | `update --check` 发现可更新项 | 正常，不是错误 |

脚本化使用时区分 `0` 与 `4`：后者表示「有更新但没执行」。

## 已知限制

- 只支持 x64 Windows 10 / 11
- 只支持 Windows PowerShell 5.1（不保证 pwsh 7 下可用）
- 静态 HTML 解析不执行 JS；需要渲染或点击的站点可用 `fetchWith: "browser"` / `click`，但不处理登录与验证码
- 环境变量与 PATH 只覆盖「当前用户」与「本机全部用户」，快捷方式始终为当前用户创建
- 下载能力只有一档（FluxDown CLI），它不可用时没有 `Invoke-WebRequest` 兜底
- 解压首选 `7-Zip-CLI`，退路只有系统 `tar.exe` 与 `Expand-Archive`（仅 zip）
- 不记录环境变量 / PATH 的原始值：卸载时只按台账回收 winst 写过的项
- 单进程锁只协调同一数据目录下的本机进程；多机共用 `pkgDir` 时，并发写同一索引文件仍是「后完成者覆盖」
