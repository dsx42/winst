# AGENTS.md

Windows 软件包管理器，Windows PowerShell 5.1 实现。入口 `winst.ps1` → `Modules\Winst.*` 各模块 → 业务逻辑；`manifest.json` 是软件目录，`build.cmd`（逻辑在 `build.ps1`）打包发布。

本目录**不是 git 仓库**（无 `.git`），不要假设有 `git log` / `git blame` / 分支操作。

## 硬性约束（最容易踩）

- **`.ps1` / `.psm1` / `.psd1` 必须 UTF-8 with BOM**。Windows PowerShell 5.1 读无 BOM 文件按系统 ANSI（本机 cp936），中文会变成乱码且不报错。源文件格式由开发者保证：`build.ps1` 发现缺 BOM 或用 LF 会直接报错并列出文件，不会自动改写。
- **`build.cmd` 必须 GBK（cp936）**，而且它只是薄壳（`powershell -File build.ps1 %*`）。用 UTF-8 编辑器保存会让中文提示变乱码，而批处理仍会"看似跑通"。打包逻辑写进 `build.ps1`，不要加回 `build.cmd`。
- 换行统一 CRLF（含 Markdown）。编辑 `.psd1` / `.ps1` 时不要用 PS 5.1 的 `Set-Content -Encoding UTF8`——它会写出无 BOM 文件；用 `[IO.File]::WriteAllText` 配 `New-Object System.Text.UTF8Encoding($true)`。
- winst **自己写出**的文件（config / state / 缓存索引 / 侧车 / `.list`）一律 UTF-8 **无** BOM（见 `Write-FileAtomic`）。

## 模块机制（决定怎么写代码）

- `.psm1` 依次点源 `Private\**\*.ps1` → `Public\**\*.ps1`（按路径排序），再用 AST 从 `Public\` 收集函数名导出。**新增 `Public\Foo.ps1` 不用改加载器、不用改入口、不用改构建脚本**。
- 函数文件**只能定义函数**，不能在加载期执行逻辑（依赖的函数可能尚未加载）。唯一例外是 `Winst.Core\Private\WinstState.Type.ps1` 的 `Add-Type`。
- 导出与否只由所在目录决定（`Public\` 导出，`Private\` 不导出）。约定一个文件一个函数、文件名与函数名一致。**把函数在 `Public\` / `Private\` 之间移动会改变可见性**：`Private\` 的函数在其它模块里运行时找不到，跨模块使用的一律放 `Public\`。
- 依赖必须单向。**刻意不用 `RequiredModules`**：那会让 `Import-Module` 去 `PSModulePath` 找模块，破坏"解压到任意目录即可运行"。依赖关系写在各自 `.psd1` 头部注释里，必须与代码实际调用一致。
- **没有模块清单文件，也不维护加载顺序**：`winst.ps1` 与 `build.ps1` 都按 `Modules\` 下的目录自动发现模块（目录名与其中清单同名即算）。顺序按目录名排序；由于函数文件只定义函数，顺序不影响正确性。新增/重命名模块只动目录，不改脚本。
- 两种形态并存：开发树是多模块（`Modules\Winst.<名>\<名>.psd1`），release 是 `build.ps1` 合并出的单一模块（`Modules\Winst\`）。`winst.ps1` 按 `Modules\` 下模块目录的个数自动判定，只有 1 个就是单一模块。

## 分层（新增函数前先想清楚放哪一层）

依赖方向严格单向，`Core` 零依赖，`App` 在最上：

```
Core                      上下文、配置、路径安全、原子 IO、JSON、状态、参数/字段读取、纯格式化
Logging / Version         Logging 不依赖任何模块；Version 只依赖 Core
Net                       Core
Ui                        Core、Logging        ← 只放「怎么显示 / 怎么读输入」的原语
System                     Core、Version
Manifest                   Core、Version
Store                      Core、Version、Net、System
Browser                    Core、Net
Engine                     Core、Net、Store、Version
Catalog                    Core、Net、Browser、Version、Manifest、Store、Engine
Install                    Core、Logging、Ui、Version、Manifest、Store、System、Net、Engine、Catalog
App                        Core、Logging、Ui、Version、Manifest、Store、Install、Catalog
```

放置原则：

- **纯函数**（只做字符串 / 路径 / 字段解析或格式化，不读盘不联网）放 `Core`，这样任何层都能用。典型：`Get-EntryString` 系列、`Format-*`、`Get-FileNameFromUrl`、`Get-WinstMainProgram`、`Clear-WinstInstallDir`。
- **`Ui` 只放原语**：渲染一行、读一个输入、格式化一句文案。需要自己查台账 / 查软件源才能拼出来的「页面」（详情页、计划页、列表页装配）属于 `App` 或对应领域模块，不要塞进 `Ui`——那会把 `Ui` 拖成依赖所有模块，和 `Install` 形成环。
- **编排与展示分层**：业务流程（安装 / 卸载 / 更新 / 修复）在 `Install` 等模块；只在 CLI 或菜单入口用一次的输入输出装配放 `App`。
- 判据：如果某个函数需要调用比自己所在层更高的模块，说明它放错层了——先考虑改成「由调用方传入数据」，再考虑移动。

## 跨模块状态

- 状态只能通过 `Get/Set/Test/Remove-WinstState`（底层是 `Winst.State` 静态字典）。直接写 `$script:` 变量别的模块看不到。
- `Initialize-WinstState` 必须在任何业务代码前执行一次；`Set-StrictMode -Version 2` 下读未初始化条目得 `$null`，紧接着取成员就抛异常。状态项在这里集中声明，新增状态项要同时加到初始化里。
- **`Set-WinstState` 返回存入的值**：赋值语句必须写 `$null = Set-WinstState ...`，否则返回值漏进函数输出流，调用方拿到数组而不是退出码。
- 进程内缓存（HTTP、JSON 解析、目录聚合、系统快照）都挂在这些状态项上，由 `Reset-*Cache` 系列失效。**写入方负责失效**：写文件走 `Write-FileAtomic`（自动失效 JSON 缓存），写台账 / 索引后调用对应的 `Reset-*`。
- **台账一律走条目级写入** `Save-WinstInstalledAppEntry`（重读最新 → 只覆盖这一条 → 盖章 `installedAt` / `updatedAt` → 原子落盘）。不要拿流程开始时读到的 `$state` 直接 `Save-WinstState` 整份写回：一次安装流程中途可能自动安装 / 更新引擎或 winst 自身，旧快照会把这些记录抹掉或把版本号回滚。缓存索引同理（`Update-WinstPackageCacheIndex` 写回前重读）。
- **台账读取有进程内缓存**（`WinstStateReadCache`，按文件戳失效）：`Read-WinstState` 命中时返回 `Copy-WinstState` 的副本，调用方可以就地改条目但不会污染缓存。`Save-WinstState` 落盘后立即刷新缓存，所以「写完再读」仍是命中。由此产生一条约定：**条目内的数组 / 嵌套字典按引用共享，写台账必须整条替换**（`Set-WinstInstalledApp`），不要就地改 `appliedEnv` / `uninstall` 里的元素。

## CLI 约定

- `winst.ps1` **不用 `param()` / `CmdletBinding()`**：`--force`、`--pkg-dir=x` 这类长开关会被参数绑定器判为未知参数直接报错。参数一律从 `$args` 读。
- `winst.ps1` 显式拒绝点源加载（`. .\winst.ps1` 只打一条警告就返回），验证时请用 `-File` 运行。
- 全局开关在命令前后都有效；子命令自己解析其余 token。新增开关要同时处理 `--x <值>` 与 `--x=<值>`。
- 退出码：`0` 成功 / 取消，`1` 参数或内部错误（含「已有另一个 winst 在运行」），`2` 网络，`3` 安装 / 卸载 / 校验失败，`4` = `update --check` 发现可更新项（**不是错误**）。

## 命令

没有测试框架、没有 lint、没有 CI。改完必须手动验证：

```powershell
# 1. 全部脚本语法（最快的兜底，先跑这个）
powershell -NoProfile -Command 'Get-ChildItem Modules -Recurse -Filter *.ps1 | ForEach-Object { $e=$null; [void][Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$null,[ref]$e); if($e){ "$($_.Name): $($e[0].Message)" } }'

# 2. 入口能起来（开发树 = 多模块形态）
powershell -NoProfile -ExecutionPolicy Bypass -File .\winst.ps1 -v

# 3. 只读命令
powershell -NoProfile -ExecutionPolicy Bypass -File .\winst.ps1 help
powershell -NoProfile -ExecutionPolicy Bypass -File .\winst.ps1 config list

# 4. 打包（结果只取决于源文件；非交互环境用 CI=1 或 -NoPause 跳过结尾等待）
$env:CI='1'; cmd /c build.cmd
```

- `powershell`（5.1）才是目标运行时。本机也装了 pwsh 7，`-v` 在 7 下能跑，但 `CompatiblePSEditions = @('Desktop')`，不要拿 pwsh 的行为当基准。
- 冷启动：开发树要逐个 `Import-Module` 并点源全部函数文件，明显慢于 release 单一模块。别为了快速检查反复跑完整入口，先跑第 1 步语法检查。
- `build.cmd` 自己会跑一次「暂存树 `winst.ps1 -v`」做冒烟，所以打包成功就等于入口能起来；但语法错误会先被合并后的解析拦住。
- 开发时改完模块设 `WINST_DEV=1`，入口会带 `-Force` 重新导入，避免模块缓存。
- `winst` 默认写 `%USERPROFILE%\.winst` 和 `%USERPROFILE%\winst`。**实验前先隔离**：
  ```powershell
  $env:WINST_HOME = "$env:TEMP\winst-dev"
  $env:WINST_INSTALL_ROOT = "$env:TEMP\winst-dev\root"
  $env:WINST_PKG_DIR = "$env:TEMP\winst-dev\apps"
  ```
  `list` / `search` / `info` / `update` 会联网刷新软件源，`--offline` 可避免。

## 关键位置

| 关注点 | 位置 |
|---|---|
| 版本号（**唯一来源**） | `Modules\Winst.Core\Public\WinstConstants.ps1` → `Get-WinstProductVersion` |
| 构建 / 打包 | `build.ps1`（`build.cmd` 只是薄壳） |
| 模块发现（两种形态） | `winst.ps1` 的 `Get-WinstModulePlan` |
| CLI 解析 / 分发 / 退出码 | `Winst.App`（`Read-WinstCommandLine`、`Invoke-WinstCommand`、`Invoke-WinstApplication`） |
| 六种下载来源解析 | `Winst.Catalog\Private\Resolve-*Source.ps1` |
| 安装决策与七阶段流程 | `Winst.Install`（`Resolve-WinstInstallDecision`、`Invoke-WinstAppInstall`） |
| 版本检测 | `Winst.Install\Private\Get-WinstVersionFrom*.ps1` |
| 状态文件格式 | `Winst.Store`（`Read/Save-WinstState`、`Read/Save-WinstCacheIndex`） |
| 单进程校验 | `Winst.App`（`Confirm-WinstSingleInstance`）+ `Winst.Core`（`Enter/Exit-WinstInstanceLock`、`Get-WinstInstanceLockPath`） |
| 路径安全 | `Winst.Core`（`Resolve-WinstSafeChildPath`、`Test-WinstSafePathSegment`、`Test-WinstPathUnderRoot`、`Test-WinstProtectedDirectory`） |
| 命令行转义 | `Winst.Core\Public\Format-WinstCommandArgument.ps1`、`Test-WinstArgumentSafe.ps1` |
| 技术文档 | `docs\`（改行为要同步；README 只放使用者视角） |
| 清单字段与枚举（第三方编写依据） | `docs\manifest.md` |

## 清单文档（`docs\manifest.md`）的编写要求

`docs\manifest.md` 是**第三方编写软件源的唯一参考**。第三方拿不到源码，只能照文档写；文档少写一个取值，对方就写不对，表现为「我的清单为什么刷新失败」。因此这份文档的标准高于其它文档：**必须详尽，宁可重复也不省略**。

硬性要求：

- **每个枚举值必须列全**，不能写「等」「之类」「其它」。涉及：`type`、`source.kind`、各 kind 的 `versionFrom`、`versionKind`、`sort`、`fetchWith`、`hashFrom`、`refresh`、`compare`、`detect.method`、`portableMode`、`uninstall` 内部方法、`link` / `click` 的条件键。
- **每个 kind 必须写清可用字段与互斥关系**：哪些字段只对该 kind 有效、哪些写法互斥（如 `link` 与 `click`）、哪些取值必须搭配（如 github 的 `versionFrom: file` 必须同时写 `versionKind` 或 `versionBetween`）。
- **每个字段必须标注默认值与适用类型**。类型差异（`installer` 忽略 `env` / `shortcuts` / `postInstall` 等；`file` 忽略 `mainExe`；`download` 忽略全部安装字段）必须显式列出，否则第三方会以为写了就生效。
- **约束要写成可验证的事实**：能写什么、不能写什么、写错时的报错文案。禁止只写「按需配置」「视情况而定」。
- **示例必须能被真实解析器接受**。加字段或改枚举时，同步更新文档，并用真实清单跑一次刷新验证。
- **改代码即改文档**：新增 / 重命名 / 删除任何清单字段或枚举取值时，同一次改动里更新 `docs\manifest.md`；反之文档里出现的字段必须能在代码里找到读取点。

自检方法（改完清单相关代码后执行）：

```powershell
# 提取代码实际读取的清单字段，与文档比对，找出「代码读但文档没写」的字段
Get-ChildItem Modules -Recurse -Filter *.ps1 |
    Select-String -Pattern "-Key\s+'([^']+)'" |
    ForEach-Object { $_.Matches[0].Groups[1].Value } |
    Sort-Object -Unique
```

比对时排除内部字段（解析锁 / 台账 / 缓存索引 / 配置项里的 `appliedEnv`、`remoteFresh`、`fileMeta`、`manifestOrigin` 等），它们由 winst 自己写，不属于清单可写字段。


## 发布相关

- `manifest.json` **不打进 `winst.zip`**，它通过 `raw.githubusercontent.com/dsx42/winst-manifest/main/manifest.json` 作为内置软件源分发（独立仓库，只放清单文件，**没有 release**）。改它就是给所有用户发布新目录，`_manifestVersion` 要一起改。
- 内置源名是 `dsx42/winst-manifest`；`dsx42/winst` 是该源的历史名称，现在只承载 winst 本体源码与 release。历史源名由 `Get-WinstRetiredManifestSourceList` 维护，`Ensure-OfficialManifest` 会清掉源列表里的残留条目与它的缓存，`Add-RemoteManifest` 拒绝再用它添加来源。
- `winst.zip` 内容固定为 `winst.ps1` + `winst.cmd` + `LICENSE` + `Modules\Winst\`（单一模块；不含 `README.md`、`docs\`、`build.*`、`install.ps1`、`manifest.json`）；`build.ps1` 会校验必需条目与"不能有单一顶层目录"。
- 构建先清空 `dist\`，再产出可运行的 `dist\winst\`，最后压缩成 `dist\winst.zip`；测产物直接跑 `dist\winst\winst.cmd`，不必解压。
- `dist\winst\` 比 `winst.zip` 多一个 `manifest.json`：构建末尾把仓库根目录的清单复制进去，产物目录因此可以直接当「脚本同目录」测本地软件源条目。复制发生在打包之后，**它不进 zip**，release 资产保持干净。
- 产物名固定不带版本号（`dist\winst.zip` + `winst.zip.sha512`），tag 用 `v<版本>`，版本号必须与 `Get-WinstProductVersion` 一致。
- 改完代码只需 `build.cmd`：它自动发现模块、校验源文件编码、算好导出名单、冒烟启动一次。**不要为新增模块/函数去改 `winst.ps1` 或 `build.ps1`**。
- 版本号由开发者确定：改 `WinstConstants.ps1` 的 `Get-WinstProductVersion`，构建只读取并打印它来自哪个文件，不写回任何东西。
- `install.ps1` 通过 `irm | iex` 执行，受硬约束限制：不用 `param()`、不用 `$PSScriptRoot`、不用 `exit`、不依赖本地文件。安装逻辑本身在 `Install-WinstSelf`，不要在这里加第二套实现。用 `Start-Process -ArgumentList` 传路径时**必须自己加引号**（数组会被空格拼接，含空格的路径会被截断）。

## 外部进程的调用约定

- 拼接命令行一律走 `Format-WinstCommandArgument`（按 `CommandLineToArgvW` 规则加引号），拼之前用 `Test-WinstArgumentSafe` 拦住引号与控制字符。`Start-Process -ArgumentList` 收到数组时不会加引号，必须自己序列化。
- 需要读退出码时用 `ProcessStartInfo` / `Start-Process -PassThru` 且确认拿到 `ExitCode`；拿不到就明确提示，不要当成成功或失败。
- 需要隔离控制台（版本探测、下载引擎、无头浏览器）走 `Invoke-WinstCapturedCommand`（`CreateNoWindow` + 三路重定向 + 立即关 stdin）。

## 文档与注释

**一律用中文。** 注释、SYNOPSIS、`.psd1` 的 `Description`、`docs\`、README 都用中文书写。

- 例外：代码标识符、函数名、参数名、清单字段名、文件路径、CLI 开关、日志中的原文引用保持原样
- 例外：`#Requires`、`#region` 这类 PowerShell 关键字行，以及 `#>` / `<#` 等语法标记
- 例外：`WinstState.Type.ps1` 里 `Add-Type` 的 C# 代码块（编译目标，不是注释）

**只描述当前代码。** 注释、SYNOPSIS、`docs\`、README 一律按现状写，不写演变过程。

- 不写修订记录 / 变更日志（没有「v1.2 改成…」「本轮…」这类段落）
- 不写「原来…」「以前…」「曾…」「不再…」「已废弃 / 已移除 / 已删除」，也不写「旧的 X 现在改成 Y」
- 不解释「为什么从 A 换成 B」，除非该原因仍然约束当前实现（例：「刻意不用 `RequiredModules`，因为它会走 `PSModulePath`」——这条保留，它决定现在怎么写）
- 代码确实需要兼容时，说明**现在接受什么**，不追溯旧名字（例：「`exe` 与 `file` 同义」而不是「`exe` 是旧名」）
- 被删掉的东西直接不提，不用留「这里以前有 X」的占位注释
- **不写会随代码变动的具体数字**（函数个数、文件数、条目数）。这类统计每次改代码都会失真；要表达规模就用「多个模块」「数十个来源解析器」这类不随细节漂移的说法。

## 不要做

- 不要把软件定义（URL、版本、下载规则）写进脚本；一切只在清单里。
- 不要用 PowerShell 默认的大小写不敏感比较处理 id：台账 / 缓存 / 清单合并一律 `New-WinstOrdinalDictionary`（Ordinal）。
- 不要为失败路径加静默兜底（猜地址、猜版本、静默跳过）；本项目要求明确报错。
- 不要在清单里声明的路径上直接拼 `Join-Path` 后就用：相对路径一律过 `Resolve-WinstSafeChildPath`（含通配用 `Resolve-WinstSafeChildPattern`），删除前过 `Test-WinstProtectedDirectory` 与重解析点检查。
- 不要让 `Ui` 依赖业务模块。展示层需要数据时，由调用方把数据传进来，而不是让 `Ui` 自己去查。
