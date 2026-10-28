# AGENTS.md

Windows 软件包管理器，Windows PowerShell 5.1 实现。入口 `winst.ps1` → `Modules\Winst.*` → 业务逻辑；`build.cmd`（逻辑在 `build.ps1`）打包发布。本目录是 git 仓库，`dist/` 与 `manifest.json` 已 gitignore。

## 硬性约束

| 对象 | 要求 |
|---|---|
| `.ps1` / `.psm1` / `.psd1` | UTF-8 **with** BOM + CRLF。5.1 按系统 ANSI 读无 BOM 文件，中文静默乱码；`build.ps1` 会列出违规文件，不自动修 |
| `install.ps1` | UTF-8 **无** BOM，且不写 `#Requires`（经 `irm \| iex` 执行，U+FEFF 会被当成命令名的一部分） |
| `build.cmd`、`winst.cmd` | **GBK（cp936）**，否则中文提示 / 注释乱码；两者都不在 `build.ps1` 的编码校验范围内 |
| winst 写出的文件 | config / state / 索引 / sidecar / `.list` 一律 UTF-8 **无** BOM（见 `Write-FileAtomic`） |

写 `.ps1` 不要用 `Set-Content -Encoding UTF8`（PS 5.1 会写出无 BOM 文件），用 `[IO.File]::WriteAllText` + `New-Object System.Text.UTF8Encoding($true)`。

## 模块机制

- `.psm1` 按路径排序点源 `Private\**` → `Public\**`，再用 AST 从 `Public\` 收集导出名。新增 `Public\Foo.ps1` 不用改加载器 / 入口 / 构建脚本。
- 函数文件**只定义函数**，加载期不能执行逻辑（唯一例外：`WinstState.Type.ps1` 的 `Add-Type`）。
- 导出只由目录决定：`Public\` 导出、`Private\` 不导出；跨模块使用一律放 `Public\`。约定一个文件一个函数（`WinstConstants.ps1`、`WinstState.ps1` 这类集中定义的除外）。
- 依赖单向，**刻意不用 `RequiredModules`**（会去 `PSModulePath` 找模块，破坏「解压到任意目录即可运行」）。依赖写在各 `.psd1` 头部注释里，必须与代码实际调用一致。
- 模块由 `Modules\` 下的目录自动发现（目录名 = 清单名），没有集中的模块列表；`winst.ps1` 按模块目录个数判定「开发树 / release 单一模块」。

## 分层

```
Core        零依赖：上下文、配置、路径安全、原子 IO、JSON、状态、字段读取、纯格式化
Logging     无依赖
Version     Core
Net         Core
Ui          Core、Logging（只放显示 / 读输入的原语）
System      Core、Version
Manifest    Core、Version
Store       Core、Version、Net、System
Browser     Core、Net
Engine      Core、Net、Store、Version
Catalog     Core、Net、Browser、Version、Manifest、Store、Engine
Install     Core、Logging、Ui、Version、Manifest、Store、System、Net、Engine、Catalog
App         Core、Logging、Ui、Version、Manifest、Store、Install、Catalog
```

- 纯函数（字符串 / 路径 / 字段解析，不读盘不联网）放 `Core`；删文件的原语（`Clear-WinstInstallDir`）也在 `Core`，但它们不是纯函数。
- 需要查台账 / 查软件源才能拼出的「页面」放 `App` 或对应领域模块，不要塞进 `Ui`（会把 `Ui` 拖成依赖所有模块、与 `Install` 成环）。
- 判据：函数要调用比自己层更高的模块，就是放错层了——优先改成由调用方传数据。

## 状态与台账

- 跨模块状态只走 `Get/Set/Test/Remove-WinstState`；`Initialize-WinstState` 必须先执行，新增状态项同时加到初始化里（StrictMode 2 下未初始化取成员会抛）。
- `Set-WinstState` 返回存入值：赋值要写 `$null = Set-WinstState ...`，否则返回值漏进输出流。
- 进程内缓存挂在状态项上，写入方负责失效：写文件走 `Write-FileAtomic`（自动清 JSON 缓存），写台账 / 索引后调对应 `Reset-*`。
- 台账走条目级写入 `Save-WinstInstalledAppEntry`（重读 → 只覆盖这一条 → 盖章 → 原子落盘）；**不要**拿流程开始时的 `$state` 整份回写（中途可能自动装引擎 / winst）。唯一例外：`Invoke-Repair` 用 `Save-WinstRepairState` 整份写回。缓存索引同理（`Update-WinstPackageCacheIndex` 写回前重读）。
- `Read-WinstState` 命中缓存时返回副本，但条目内数组 / 嵌套字典按引用共享：写台账必须整条替换（`Set-WinstInstalledApp`），不要就地改 `appliedEnv` / `uninstall`。

## CLI 与验证

- `winst.ps1` 不用 `param()` / `CmdletBinding()`（`--force`、`--pkg-dir=x` 会被绑定器拒），参数从 `$args` 读；不支持点源加载，验证用 `-File`。
- 全局开关在命令前后都有效；新增开关要同时支持 `--x <值>` 与 `--x=<值>`。
- 退出码：`0` 成功 / 取消，`1` 参数或内部错误（含已有实例在运行；`manifest add` 拉取失败），`2` 网络（`install` / `update` / `manifest update`），`3` 安装 / 卸载 / 校验失败，`4` = `update --check` 有可更新项（**不是错误**）。

没有测试框架、lint、CI，改完必须手动验证：

```powershell
# 1. 语法（先跑这个；在 PowerShell 会话里直接粘）
Get-ChildItem Modules -Recurse -Filter *.ps1 |
    ForEach-Object { $e=$null; [void][Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$null,[ref]$e); if($e){ "$($_.Name): $($e[0].Message)" } }

# 2. 入口（开发树）
powershell -NoProfile -ExecutionPolicy Bypass -File .\winst.ps1 -v
powershell -NoProfile -ExecutionPolicy Bypass -File .\winst.ps1 config list

# 3. 打包（非交互加 CI=1；自带暂存树冒烟）
$env:CI='1'; cmd /c build.cmd
```

- 目标运行时是 `powershell` 5.1（`CompatiblePSEditions = Desktop`），不要拿 pwsh 7 的行为当基准。
- 开发树冷启动慢（逐个 `Import-Module`），别反复跑完整入口；改完模块可设 `WINST_DEV=1` 强制重新导入。
- 实验前隔离：`WINST_HOME` / `WINST_INSTALL_ROOT` / `WINST_PKG_DIR` 指到 `%TEMP%` 下；`list` / `search` / `info` / `update` 会联网，`--offline` 可避免。

## 关键位置

| 关注点 | 位置 |
|---|---|
| 版本号（唯一来源） | `Modules\Winst.Core\Public\WinstConstants.ps1` → `Get-WinstProductVersion` |
| 构建 / 打包 | `build.ps1` |
| 模块发现 | `winst.ps1` 的 `Get-WinstModulePlan` |
| CLI 解析 / 分发 / 退出码 | `Winst.App`（`Read-WinstCommandLine`、`Invoke-WinstCommand`、`Invoke-WinstApplication`） |
| 下载来源解析 | `Winst.Catalog\Private\Resolve-*Source.ps1`，分派器 `Public\Resolve-AppSource.ps1` |
| 安装决策 / 七阶段流程 | `Winst.Install`（`Resolve-WinstInstallDecision`、`Invoke-WinstAppInstall`） |
| 版本检测 | `Winst.Install\Private\Get-WinstVersionFrom*.ps1` |
| 状态文件格式 | `Winst.Store`（`Read/Save-WinstState`、`Read/Save-WinstCacheIndex`） |
| 单进程锁 | `Winst.App\Confirm-WinstSingleInstance` + `Winst.Core\Enter/Exit-WinstInstanceLock` |
| 路径安全 / 命令行转义 | `Winst.Core`：`Resolve-WinstSafeChildPath`、`Test-WinstSafePathSegment`、`Test-WinstPathUnderRoot`、`Test-WinstProtectedDirectory`、`Format-WinstCommandArgument`、`Test-WinstArgumentSafe` |
| 文档 | `docs\`（改行为同步）；第三方清单规范 `docs\manifest.md` |

## 清单文档（`docs\manifest.md`）

它是第三方编写软件源的**唯一参考**，标准高于其它文档：每个字段写清默认值、适用类型、互斥与搭配关系；每个枚举值必须列全（不写「等」「其它」）；约束写成可验证事实（能写什么、写错报什么）；示例必须能被真实解析器接受。**改清单字段或枚举 = 同一改动里改文档**，反之文档里出现的字段必须能追到读取点。

字段自检（排除 `appliedEnv`、`remoteFresh`、`fileMeta`、`manifestOrigin` 等 winst 自写字段）：

```powershell
Get-ChildItem Modules -Recurse -Filter *.ps1 | Select-String -Pattern "-Key\s+'([^']+)'" |
    ForEach-Object { $_.Matches[0].Groups[1].Value } | Sort-Object -Unique
```

## 发布

- `winst.zip` = `winst.ps1` + `winst.cmd` + `LICENSE` + `Modules\Winst\`（不含 `README.md`、`docs\`、`build.*`、`install.ps1`、`manifest.json`）；`build.ps1` 校验必需 / 禁止条目与「不能有单一顶层目录」。
- 产物 `dist\winst.zip` + `dist\winst.zip.sha512`，名字不带版本号；tag 用 `v<版本>`，版本号只来自 `Get-WinstProductVersion`。
- `dist\winst\` 可直接跑，不必解压；仓库根有 `manifest.json` 时会复制进去做本地源测试，**不进 zip**。
- 正式目录在独立仓库 `dsx42/winst-manifest`（无 release），经 `raw.githubusercontent.com/dsx42/winst-manifest/main/manifest.json` 分发；改那边才是发布，`_manifestVersion` 一起改。本仓库的 `manifest.json` 只是本地副本。
- 内置源名 `dsx42/winst-manifest`，`Ensure-OfficialManifest` 负责补首位 / 恢复地址 / 挪回首位。
- `install.ps1` 经 `irm | iex` 执行：不用 `param()`、不用 `$PSScriptRoot`、不用 `exit`、不依赖本地文件；安装逻辑在 `Install-WinstSelf`，用 `Start-Process -ArgumentList` 传路径必须自己加引号。

## 外部进程

- 命令行一律走 `Format-WinstCommandArgument`，拼之前用 `Test-WinstArgumentSafe` 拦引号与控制字符（数组传给 `-ArgumentList` 不会自动加引号）。
- 读退出码用 `ProcessStartInfo` / `Start-Process -PassThru` 并确认拿到 `ExitCode`；拿不到就明确提示，不要猜成功或失败。
- 需要隔离控制台（版本探测、下载引擎、无头浏览器）走 `Invoke-WinstCapturedCommand`（`CreateNoWindow` + 三路重定向 + 立即关 stdin）。

## 文档与注释

- **一律中文**（标识符、字段名、路径、CLI 开关、`#Requires` 等关键字与 C# 代码除外）。
- **只描述当前代码**：不写变更记录、不写「原来 / 已废弃」、不解释「为什么从 A 换成 B」（除非该原因仍约束当前实现）。
- 不写会随代码漂移的具体数字（函数数、文件数、条目数）。

## 不要做

- 不要把软件定义（URL、版本、下载规则）写进脚本，只放清单。
- 不要用大小写不敏感比较处理 id：台账 / 缓存 / 清单合并一律 `New-WinstOrdinalDictionary`。
- 不要为失败路径加静默兜底（猜地址、猜版本、静默跳过），要明确报错。
- 不要在清单声明的路径上直接 `Join-Path` 就用：相对路径过 `Resolve-WinstSafeChildPath`（含通配用 `Resolve-WinstSafeChildPattern`），删除前过 `Test-WinstProtectedDirectory` 与重解析点检查。
- 不要让 `Ui` 依赖业务模块。
