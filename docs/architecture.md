# 架构

## 设计目标

| 目标 | 落地方式 |
|---|---|
| 单进程、零外部运行时 | Windows PowerShell 5.1 自带能力；下载与解压使用 winst 自己安装的引擎 |
| 逻辑与数据分离 | 脚本不含软件定义，`manifest.json` 才是软件来源 |
| 绿色免安装 | 入口按绝对路径 `Import-Module`，不依赖 `PSModulePath` |
| 启动快 | release 合并为单一模块，只需一次 `Import-Module` |
| 边界清晰 | 依赖单向：`Core` 在最底层，`App` 在最上层 |
| 可替换实现 | 跨模块状态、持久化、HTTP 封装在模块函数后 |

## 两种模块形态

同一份代码有两种磁盘布局，`winst.ps1` 自动发现 `Modules\` 下「目录名与其中清单同名」的模块：

| 形态 | 布局 | 用途 |
|---|---|---|
| 多模块 | `Modules\Winst.<名>\<名>.psd1` | 开发树：逐个导入，修改后可直接重跑 |
| 单一模块 | `Modules\Winst\Winst.psd1` + `Winst.psm1` | release：`build.ps1` 合并生成，一次导入 |

只有一个模块目录时按单一模块处理，多个则逐个导入；非模块目录、缺少同名清单或没有任何模块都会明确报错。没有额外的模块清单文件，新增、删除或重命名模块无需修改 `winst.ps1` 与 `build.ps1`。

## 分层与依赖

依赖严格单向，每个模块只能调用同层或更下层的模块，`Core` 零依赖：

```
  Winst.App          组合根：CLI 解析、命令分发、菜单编排、页面装配
  ──────────────────────────────────────────────────────────────
  Winst.Install      安装 / 更新 / 卸载 / 修复 / 自更新
  Winst.Catalog      来源解析、计划生成、目录聚合与详情数据、源刷新
  ──────────────────────────────────────────────────────────────
  Winst.Engine       下载与解压引擎封装
  Winst.Store        台账、缓存索引、清单文件、完整性
  Winst.Browser      Edge 无头抓取与点击取址
  Winst.Manifest     清单缓存、源列表、sidecar
  Winst.System       注册表 / Appx / 环境变量 / 快捷方式
  Winst.Ui           展示与输入原语（不读业务数据）
  Winst.Net          HTTP 与响应缓存
  Winst.Version      版本比较、识别、改写、占位符
  Winst.Logging      区块标题
  ──────────────────────────────────────────────────────────────
  Winst.Core         上下文、配置、路径安全、IO、JSON、状态、字段读取、纯格式化
```

具体依赖写在各 `.psd1` 头部注释中。刻意不使用 `RequiredModules`：它会让 `Import-Module` 去 `PSModulePath` 查找模块，破坏「解压到任意目录即可运行」。

两条边界：

- **`Ui` 不查业务数据**：只渲染传入内容；需要台账或软件源才能拼出的页面放在 `App` 或对应领域模块，避免 `Ui` 与 `Install` 形成依赖环。
- **纯函数放 `Core`**：只做字符串、路径、字段解析或格式化的函数放最底层，避免上层为工具函数反向依赖。

## 模块职责

| 模块 | 职责 |
|---|---|
| `Winst.Core` | 上下文与配置、路径解析与安全校验、原子文件 IO、JSON 缓存、状态容器、条目字段读取、参数转义、匹配规则、纯格式化 |
| `Winst.Logging` | 统一的区块标题输出 |
| `Winst.Version` | 版本比较与规范化、`versionKind` / `versionBetween` / `versionRewrite`、版本占位符 |
| `Winst.Net` | HTTP GET/HEAD、代理尝试、进程内响应缓存、HTML 锚点、外部校验文件抓取 |
| `Winst.Ui` | 菜单循环、确认与多选输入、列表分页、单行渲染、格式化文案 |
| `Winst.System` | 注册表卸载项、Appx 包、环境变量与 PATH、快捷方式、运行进程 |
| `Winst.Manifest` | 源列表、清单缓存、本地清单识别、sidecar 元数据 |
| `Winst.Store` | 安装台账与读缓存、缓存索引、安装包与文件级状态、摘要与完整性、清单文件读写 |
| `Winst.Browser` | 系统 Edge 无头抓页与 CDP 点击取址（`fetchWith: browser` / `source.click`） |
| `Winst.Engine` | FluxDown CLI 下载、7-Zip 解压、`stripTopDir` / `extractFiles`、包内结构派生版本 |
| `Winst.Catalog` | 各来源解析器、解析计划、源刷新与解析锁、依赖闭包、聚合视图与详情数据 |
| `Winst.Install` | 安装决策、payload 落地、系统项、版本检测、台账写入、卸载、修复、引擎与自身更新 |
| `Winst.App` | 命令行解析与分发、菜单编排、页面装配、离线套装、退出码 |

## 模块结构与加载

```
Modules\Winst.Store\
├── Winst.Store.psd1     元数据（版本、GUID、说明、依赖注释）
├── Winst.Store.psm1     加载器
├── Public\*.ps1         导出函数，一个文件一个函数
└── Private\*.ps1        内部辅助，不导出
```

`.psm1` 依次点源 `Private\` 与 `Public\` 下的文件（按路径排序），再用 AST 从 `Public\` 收集函数名并 `Export-ModuleMember`。`build.ps1` 按相同顺序合并成 release 的 `Winst.psm1`，导出名单在构建期算好，同名函数会使构建失败。

- 新增函数文件无需修改加载器、入口或构建脚本；文件名与函数名按约定一致。
- 文件只能定义函数，不能在加载期执行逻辑；跨模块使用的辅助函数必须放 `Public\`，否则其它模块无法调用。
- 被依赖函数通常到调用时才需要存在，因此按目录名排序加载不影响正确性。

## 跨模块状态与缓存一致性

PowerShell 的各模块有独立 `$script:` 作用域。`Winst.Core` 用 `Add-Type` 声明静态 `Winst.State` 字典，所有模块只通过 `Get/Set/Test/Remove/Reset-WinstState` 访问：

- `Initialize-WinstState` 必须在业务代码前执行，集中声明 CLI 选项、HTTP/JSON/目录聚合缓存、系统快照、引擎路径缓存和菜单标志；重复执行只补空项，不清空已有缓存。
- 状态只保存进程内数据，跨进程数据必须落盘（见 [data-files.md](data-files.md)）。
- `Set-WinstState` 返回存入值，调用方必须用 `$null =` 接住，避免污染函数输出流。
- `Write-FileAtomic` 写文件后失效对应 JSON 缓存；写源列表或 sidecar 后失效目录聚合缓存。台账和缓存索引有各自的读缓存与写入约定，详见数据文件文档。

安装流程可能嵌套安装或更新引擎、winst 自身。台账通过 `Save-WinstInstalledAppEntry` 重读最新文件后只覆盖目标条目，缓存索引写回前也重读，避免旧快照抹掉嵌套流程写入的记录。

winst 自更新先把 release 树放入暂存目录，再替换安装目录；`Modules\` 整棵替换并逐文件核对，保留 `lists\` 与 `*.list`。更新后的代码在下次启动生效，当前进程继续使用已加载模块。

## 入口

`winst.ps1` 负责：

1. 设置 `Set-StrictMode -Version 2`、`$ErrorActionPreference = 'Stop'`、静默进度和 TLS 1.2。
2. 记录根目录，按模块形态导入模块；`WINST_DEV=1` 时加 `-Force`。
3. 调用 `Initialize-WinstState`，再调用 `Invoke-WinstApplication`。
4. 应用层记录脚本位置、做单进程校验，再解析 CLI、分发命令或进入菜单。
5. 将结果映射为进程退出码；未捕获异常写 stderr 并退出 1。

入口刻意不使用 `param()` / `CmdletBinding()`，长开关一律从 `$args` 读取；同时拒绝点源加载，应使用 `-File` 运行。

## 代码约定

- **依赖单向**：下层模块不得调用上层模块。
- **展示分层**：渲染与输入原语在 `Winst.Ui`；`Winst.App` 负责命令与流程编排。
- **不做静默兜底**：来源解析、校验或必需字段失败时明确报错，不猜地址或版本。
- **失败隔离**：批量操作逐项 `try/catch`，单项失败不中断其余。
- **路径安全**：清单提供的 id、文件名和相对路径先校验再拼接；递归删除检查目标根、受保护目录与重解析点。
- **文件格式**：`.ps1` / `.psm1` / `.psd1` 为 UTF-8 with BOM，`build.cmd` 为 GBK，统一 CRLF；`build.ps1` 校验脚本编码与换行。
- **文档与注释**：使用中文，只描述当前实现。
- **id 比较区分大小写**：台账、缓存索引、清单合并统一用 Ordinal 字典（`New-WinstOrdinalDictionary`）。
