# AGENTS.md

Windows 软件包管理器，Windows PowerShell 5.1 实现。运行入口只有 `winst.ps1` 和 `winst.cmd`。`winst.cmd` 转调 `winst.ps1`，由 `winst.ps1` 调用 `Modules\Winst.*` 执行业务逻辑。模块函数仅供仓库内部使用，`Public\` 导出也无仓库外调用方。`build.cmd`（逻辑在 `build.ps1`）打包发布。本目录是 git 仓库，`dist/` 与根目录测试用 `manifest.json` 由 .gitignore 忽略；manifest.json 不参与 Git 跟踪，保留本地测试副本。

## 硬性约束

实现功能时优先使用 Windows PowerShell 5.1 原生命令。只有原生命令无法满足所需行为时才使用 .NET API。

| 对象 | 要求 |
|---|---|
| `.ps1` / `.psm1` / `.psd1` | UTF-8 **with** BOM + CRLF。5.1 按系统 ANSI 读无 BOM 文件，中文静默乱码；`build.ps1` 会列出违规文件，不自动修 |
| `install.ps1` | UTF-8 **无** BOM，且不写 `#Requires`（经 `irm \| iex` 执行，U+FEFF 会被当成命令名的一部分） |
| `build.cmd`、`winst.cmd` | **GBK（cp936）**，否则中文提示 / 注释乱码；两者都不在 `build.ps1` 的编码校验范围内 |
| winst 写出的文件 | config / state / 索引 / sidecar / `.list` 一律 UTF-8 **无** BOM（见 `Write-FileAtomic`） |

写 `.ps1` 用 `[IO.File]::WriteAllText` + `New-Object System.Text.UTF8Encoding($true)` 显式控制 BOM 与 CRLF。Windows PowerShell 5.1 的 `Set-Content -Encoding UTF8` 会写 BOM，但不同版本默认行为不同，不依赖隐式编码。

## 模块机制

- `.psm1` 按路径排序点源 `Private\**` → `Public\**`，再用 AST 从 `Public\` 收集导出名。新增 `Public\Foo.ps1` 不用改加载器 / 入口 / 构建脚本。
- 函数文件**只定义函数**，加载期不能执行逻辑（唯一例外：`WinstState.Type.ps1` 的 `Add-Type`）。
- 导出只由目录决定：`Public\` 导出、`Private\` 不导出；跨模块使用一律放 `Public\`。约定一个文件一个函数（`WinstConstants.ps1`、`WinstState.ps1` 这类集中定义的除外）。
- 依赖单向，**刻意不用 `RequiredModules`**（会去 `PSModulePath` 找模块，破坏「解压到任意目录即可运行」）。依赖写在各 `.psd1` 头部注释里，必须与代码实际调用一致。
- 模块由 `Modules\` 下的目录自动发现（目录名 = 清单名），没有集中的模块列表；`winst.ps1` 按发现的清单逐个导入，release 只含单一模块。

## 分层

```
Core        零依赖：上下文、配置、路径安全、原子 IO、JSON、状态、字段读取、纯格式化
Version     Core
Net         Core
Ui          Core（只放显示 / 读输入的原语）
System      Core、Version
Manifest    Core、Version
Store       Core、Version、Net、System
Browser     Core、Net
Engine      Core、Net、Store、Version
Catalog     Core、Net、Browser、Version、Manifest、Store
Install     Core、Ui、Version、Manifest、Store、System、Net、Engine、Catalog
App         Core、Ui、Version、Manifest、Store、Install、Catalog
```

- 纯函数（字符串 / 路径 / 字段解析，不读盘不联网）放 `Core`；删文件的原语（`Clear-WinstInstallDir`）也在 `Core`，但它们不是纯函数。
- 需要查台账 / 查软件源才能拼出的「页面」放 `App` 或对应领域模块，不要塞进 `Ui`（会把 `Ui` 拖成依赖所有模块、与 `Install` 成环）。
- 判据：函数要调用比自己层更高的模块，就是放错层了——优先改成由调用方传数据。

## 安装暂存与 clean 设计

- 绿色软件、引擎、winst 自身、包内安装器及解压附件在 `[IO.Path]::GetTempPath()` 下的 `.winst-stage` 串行暂存。安装版从本地或 UNC 缓存路径直接安装。声明 `installerExe` 时，从缓存主包解压到同一固定暂存目录，再运行包内安装器。
- 入口同时持有数据目录的 `winst.lock` 与 Temp 下的 `.winst-stage.lock`，直到业务及清理结束。暂存与安装目录互不包含，输入包位于暂存外，当前 Temp 必须与持锁位置一致。开始使用固定暂存前先检查旁边的 `.winst-stage.recovery.json`，存在即提示恢复位置并停止。普通残留用一条 `Remove-Item` 清理，失败即停止。
- 没有有效的 `extractFiles` 时，字符串 `stripTopDir` 解析到现存文件才按该文件的扩展名判断是否解到 `.winst-inner`。选中单文件或多个路径时整理到 `.winst-layout`。两者均按需创建，包内同名路径会报错。
- 绿色软件、引擎和 winst 自更新共用批量落位。`clean` 在整理 `keep` 前检查进程工作目录和 PowerShell 当前文件系统位置。任一位于安装目标的子目录即报错。命中的 `keep` 按相对路径复制到交付目录，旧文件覆盖新版同名文件，有命中才写恢复标记。工作目录等于目标时保留根目录、清空内容再复制，两者均在目标外时整删旧目录并整树复制。`overwrite` 跳过 `keep` 和删旧，将交付内容合并到目标。解压、复制与删除按命令结果判定，允许空目录，下载包仍按清单校验。
- 批量交付按普通目录树处理。为筛查重解析点或核对内容而递归扫描交付目录、已有的 `overwrite` 目标或 `keep` 命中的子树，属于过度防御。检查操作根路径和目录边界，按需定位清单路径、匹配 `keep`，命中目录后直接复制整棵子树。
- Windows PowerShell 5.1 批量复制遇到以下类型冲突时可能跳过子树，属于已接受的行为，后续评审将这两种情形排除在缺陷报告范围之外。`keep` 命中的旧目录内部有子目录而交付目录同路径是文件。`overwrite` 的新目录与旧安装同路径的文件冲突。
- 安装、更新的文件阶段只在结束时报告结果和耗时。卸载整目录时校验目标路径和目录边界，直接用 `Remove-Item` 删除并报告耗时，省去目录内的文件检查。删旧失败不开始复制。标记生效后若中断、删旧或复制失败，保留暂存供手动恢复。文件落位后先撤销标记再清暂存，任一步失败都须报告文件已落位。

## 状态与台账

- 跨模块状态只走 `Get/Set/Test/Remove-WinstState`；`Initialize-WinstState` 必须先执行，新增状态项同时加到初始化里（StrictMode 2 下未初始化取成员会抛）。
- `Set-WinstState` 返回存入值：赋值要写 `$null = Set-WinstState ...`，否则返回值漏进输出流。
- 进程内缓存挂在状态项上，写入方负责失效：写文件走 `Write-FileAtomic`（自动清 JSON 缓存），写台账 / 索引后调对应 `Reset-*`。
- 新增或替换安装记录用 `Save-WinstInstalledAppEntry`，重读台账后只更新当前软件，盖章并原子落盘。**不要**把安装流程开始时的 `$state` 整份回写，以免覆盖中途自动安装引擎或 winst 的记录。
- 卸载时，`Remove-WinstUninstallLedgerEntry` 先读最新的安装记录，只删掉当前软件再保存。修复时，`Invoke-Repair` 把扫描结果合并到安装记录中，再用 `Save-WinstRepairState` 保存。缓存索引由 `Update-WinstPackageCacheIndex` 在写回前重读。
- `Read-WinstState` 命中缓存时返回副本，但条目内数组 / 嵌套字典按引用共享：写台账必须整条替换（`Set-WinstInstalledApp`），不要就地改 `appliedEnv` / `uninstall`。

## CLI 与验证

- `winst.ps1` 不用 `param()` / `CmdletBinding()`（`--force`、`--pkg-dir=x` 会被绑定器拒），参数从 `$args` 读；不支持点源加载，验证用 `-File`。
- 全局开关在命令前后都有效；新增开关要同时支持 `--x <值>` 与 `--x=<值>`。
- 退出码：`0` 成功 / 取消，`1` 参数或内部错误（含已有实例在运行；`manifest add` 拉取失败），`2` 网络（`install` / `update` / `manifest update`），`3` 安装 / 卸载 / 校验失败，`4` = `update --check` 有可更新项（**不是错误**）。

**每次代码改动后、运行验证前，必须主动清理废弃代码。** 沿本次改动影响的调用链核对仓库内的直接调用、动态分派和构建脚本引用。在同一次改动中删除已失去用途的实现，并继续清理因此失去用途的函数、参数和分支。

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
- 实验前设置 `WINST_NO_ELEVATE=1`，避免提权重启丢失进程内的隔离环境变量。将 `WINST_HOME` / `WINST_INSTALL_ROOT` / `WINST_PKG_DIR` 指到 `%TEMP%` 下；并行实验还须分别设置 `TEMP` / `TMP` 到独立目录；`list` / `search` / `info` / `update` 会联网，`--offline` 可避免。

## 关键位置

| 关注点 | 位置 |
|---|---|
| 版本号（唯一来源） | `Modules\Winst.Core\Public\WinstConstants.ps1` → `Get-WinstProductVersion` |
| 构建 / 打包 | `build.ps1` |
| 模块发现 | `winst.ps1` 的 `Get-WinstModulePlan` |
| CLI 解析 / 分发 / 退出码 | `Winst.App`（`Read-WinstCommandLine`、`Invoke-WinstCommand`、`Invoke-WinstApplication`） |
| 下载来源解析 | `Winst.Catalog\Private\Resolve-*Source.ps1`，分派器 `Private\Resolve-WinstNormalizedAppSource.ps1` |
| 安装决策 / 七阶段流程 | `Winst.Install`（`Resolve-WinstInstallDecision`、`Invoke-WinstAppInstall`） |
| 版本检测 | `Winst.Install\Private\Get-WinstVersionFrom*.ps1` |
| 状态文件格式 | `Winst.Store`（`Read/Save-WinstState`、`Read/Save-WinstCacheIndex`） |
| 单进程锁 | `Winst.App\Confirm-WinstSingleInstance` + `Winst.Core\Enter/Exit-WinstInstanceLock` |
| 路径安全 / 命令行转义 | `Winst.Core`：`Resolve-WinstSafeChildPath`、`Test-WinstSafePathSegment`、`Test-WinstPathUnderRoot`、`Test-WinstProtectedDirectory`、`Format-WinstCommandArgument`、`Test-WinstArgumentSafe` |
| 文档 | `docs\`（改行为同步）；第三方清单规范 `docs\manifest.md` |

## 清单文档（`docs\manifest.md`）

它是第三方编写软件源的**唯一参考**，标准高于其它文档：每个字段写清默认值、适用类型、互斥与搭配关系；每个枚举值必须列全（不写「等」「其它」）；约束写成可验证事实（能写什么、写错报什么）；示例必须能被真实解析器接受。**改清单字段或枚举 = 同一改动里改文档**，反之文档里出现的字段必须能追到读取点。

- 新增软件源条目时，尽量探索并实际验证官方检查更新 API 或官方版本元数据（JSON / XML / 文本）；优先使用能正确识别目标平台、架构及正式版本的官方接口，未确认可用接口时再采用官方下载页。

用下列命令查找字段候选，再核对清单解析器的读取点，排除 UI 键和 `appliedEnv`、`remoteFresh`、`fileMeta`、`manifestOrigin` 等内部字段。

```powershell
Get-ChildItem Modules -Recurse -Filter *.ps1 | Select-String -AllMatches -Pattern "-Key\s+'([^']+)'" |
    ForEach-Object { foreach ($match in $_.Matches) { $match.Groups[1].Value } } | Sort-Object -Unique
```

## 发布

- `winst.zip` = `winst.ps1` + `winst.cmd` + `LICENSE` + `Modules\Winst\`（不含 `README.md`、`docs\`、`build.*`、`install.ps1`、`manifest.json`）；`build.ps1` 校验必需 / 禁止条目与「不能有单一顶层目录」。
- 产物 `dist\winst.zip` + `dist\winst.zip.sha512`，名字不带版本号；tag 用 `v<版本>`，版本号只来自 `Get-WinstProductVersion`。
- `dist\winst\` 可直接跑，不必解压；仓库根有 `manifest.json` 时会复制进去做本地源测试，**不进 zip**。
- 正式目录在独立仓库 `dsx42/winst-manifest`（无 release），经 `raw.githubusercontent.com/dsx42/winst-manifest/main/manifest.json` 分发；改那边才是发布，`_manifestVersion` 一起改。本仓库的 `manifest.json` 只是本地副本。
- 内置源名 `dsx42/winst-manifest`，`Ensure-OfficialManifest` 负责补首位 / 恢复地址 / 挪回首位。
- `install.ps1` 经 `irm | iex` 执行：不用 `param()`、不用 `$PSScriptRoot`、不用 `exit`、不依赖本地文件；安装逻辑在 `Install-WinstSelf`，引导脚本在 `ProcessStartInfo.Arguments` 中为入口和解压目录的路径分别加双引号。

## 外部进程

- 命令行一律走 `Format-WinstCommandArgument`，拼之前用 `Test-WinstArgumentSafe` 拦引号与控制字符（数组传给 `-ArgumentList` 不会自动加引号）。
- 读退出码用 `ProcessStartInfo` / `Start-Process -PassThru` 并确认拿到 `ExitCode`；拿不到就明确提示，不要猜成功或失败。
- 需要隔离控制台（版本探测、下载引擎、无头浏览器）走 `Invoke-WinstCapturedCommand`（`CreateNoWindow` + 三路重定向 + 立即关 stdin）。

## 文档与注释

- **一律中文**（标识符、字段名、路径、CLI 开关、`#Requires` 等关键字与 C# 代码除外）。
- **只描述当前代码**：不写变更记录、不写「原来 / 已废弃」、不解释「为什么从 A 换成 B」（除非该原因仍约束当前实现）。
- 不写会随代码漂移的具体数字（函数数、文件数、条目数）。

## 不要做

- 采用能满足当前需求的最简单实现。新增抽象、配置或防护分支前，先确认它解决哪项现有需求或哪种实际可触发的失败。同一次操作中，输入和信任边界未变时复用已有校验结果。状态可能已改变或即将执行删除、覆盖等操作时，只复核与本次操作安全相关的条件。
- 不要把软件定义（URL、版本、下载规则）写进脚本，只放清单。
- 不要用大小写不敏感比较处理 id：台账 / 缓存 / 清单合并一律 `New-WinstOrdinalDictionary`。
- 不要为失败路径加静默兜底（猜地址、猜版本、静默跳过），要明确报错。
- 不要在清单声明的路径上直接 `Join-Path` 就用：相对路径过 `Resolve-WinstSafeChildPath`（含通配用 `Resolve-WinstSafeChildPattern`），删除前过 `Test-WinstProtectedDirectory` 与重解析点检查。
- 不要让 `Ui` 依赖业务模块。
