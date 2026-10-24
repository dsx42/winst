# 开发与发布

## 仓库结构

```
winst\
├── winst.ps1                 入口（按模块形态导入 + 退出码映射）
├── winst.cmd                 双击启动器
├── manifest.json             内置软件源（独立仓库分发，构建树附测试副本，不进入 winst.zip）
├── install.ps1               一行安装引导脚本
├── build.cmd                 构建入口（GBK 批处理薄壳，转交 build.ps1）
├── build.ps1                 打包逻辑（合并模块、校验、产出 dist\）
├── LICENSE                   GPLv3 原文（随 release 分发）
├── README.md
├── docs\                     技术文档
└── Modules\
    ├── Winst.Core\           { psd1, psm1, Public\, Private\ }
    ├── Winst.Logging\
    ├── Winst.Version\
    ├── Winst.Net\
    ├── Winst.Ui\
    ├── Winst.System\
    ├── Winst.Manifest\
    ├── Winst.Store\
    ├── Winst.Browser\
    ├── Winst.Engine\
    ├── Winst.Catalog\
    ├── Winst.Install\
    └── Winst.App\
```

`build.cmd` 是 `build.ps1` 的薄壳：切到脚本目录、转交、透传参数、回传退出码。真正的逻辑全在 `build.ps1`（UTF-8 with BOM，能正常写中文、能用 PowerShell 语法检查），批处理文件只保留 cmd.exe 必需的那几行——它必须存成 GBK，写多了只会增加编码风险。

改代码前先读 [architecture.md](architecture.md)。

## 从源码运行

不需要安装、不需要配置 `PSModulePath`：

```bat
winst.cmd
winst.cmd list --cached
powershell -NoProfile -ExecutionPolicy Bypass -File .\winst.ps1 --help
```

脚本目录下的 `manifest.json` 会自动作为本地软件源；带 `apps\` 目录即自动命中离线缓存。

## 开发调试

- **改完模块要重新导入**：PowerShell 会缓存已导入的模块，设置环境变量 `WINST_DEV=1` 让入口带 `-Force` 导入
- **单模块试验**：直接 `Import-Module .\Modules\Winst.Store\Winst.Store.psd1 -Force`；跨模块调用在运行时才解析，不必按顺序先导入别的模块
- **详细日志**：`--verbose` 打印 HTTP、来源解析、文件匹配、版本检测细节；入口未捕获的异常也会带脚本堆栈
- **不写盘试跑**：`--dry-run` 只展示计划，不下载、不安装、不写台账；软件源也可能联网查询。winst 自身安装是特例，预览会明确拒绝执行
- **隔离实验**：把数据、安装与缓存目录都指到临时目录，避免污染真实数据

临时目录示例：

```powershell
$env:WINST_HOME = Join-Path $env:TEMP 'winst-dev'
$env:WINST_PKG_DIR = Join-Path $env:TEMP 'winst-dev\apps'
$env:WINST_INSTALL_ROOT = Join-Path $env:TEMP 'winst-dev\root'
.\winst.cmd config list
```

### 环境变量

| 变量 | 作用 |
|---|---|
| `WINST_HOME` | 数据目录（默认 `%USERPROFILE%\.winst`），配置与安装清单位于其下 |
| `WINST_PKG_DIR` | 安装包缓存、软件源列表与清单缓存的位置；优先于脚本同目录 `apps\` 和配置 |
| `WINST_INSTALL_ROOT` | 软件安装根目录（默认 `%USERPROFILE%\winst`），`<installRoot>\state.json` 是安装台账 |
| `WINST_DEV` | 设为 `1` 时入口用 `-Force` 重新导入模块 |
| `WINST_NO_LOCK` | 设为 `1` 时跳过单进程锁，仅用于排障；不要用它并发执行会写数据的命令 |
| `CI` | 构建时设为 `1` 可跳过结尾等待，与 `build.cmd -NoPause` 等价 |

## 编码与文件约定

| 文件 | 编码 | 说明 |
|---|---|---|
| `*.ps1` / `*.psm1` / `*.psd1` | **UTF-8 with BOM** | Windows PowerShell 5.1 按 ANSI 读无 BOM 文件，中文会乱码；`build.ps1` 发现不合规直接报错，不自动改写 |
| `build.cmd` | **GBK** | cmd.exe 在 `chcp 936` 下按该代码页解析批处理 |
| `manifest.json` / `README.md` / `docs\*.md` | UTF-8 无 BOM | |
| 换行 | CRLF | |

winst 自己写出的 JSON / `.list` 一律 UTF-8 无 BOM。

## 代码约定

1. **依赖单向**：`Core` 在最底，`App` 在最上，禁止下层调用上层
2. **文件里只定义函数**：加载期不执行逻辑，依赖的函数可能还没加载
3. **导出与否看目录**：要导出的放 `Public\`，辅助函数放 `Private\`
4. **一个文件一个函数**，文件名与函数名保持一致
5. **不静默兜底**：解析失败、校验失败、字段缺失一律明确报错
6. **失败隔离**：批量操作逐项 `try/catch`，单项失败不中断其余
7. **状态只放一次运行内的东西**：跨进程数据必须落盘
8. **id 比较用 Ordinal**（`New-WinstOrdinalDictionary`），不能用 PowerShell 默认的不区分大小写比较
9. **文案风格**：面向普通用户，一句话说清「下一步做什么」；技术细节只在 `--verbose` 出现

## 新增一个模块

1. 建目录 `Modules\Winst.Foo\`，放 `Winst.Foo.psd1`（可复制现有模块改 `RootModule` / `GUID` / `Description` / 依赖注释）、`Winst.Foo.psm1`（照抄加载器）、`Public\`、`Private\`
2. 在依赖它的模块的 `.psd1` 头部注释里补一行

不用改 `winst.ps1` 或 `build.ps1`：两者都按 `Modules\` 下的目录自动发现模块。合并进单一模块的顺序就是目录名排序，因为函数文件只定义函数、加载期没有互相调用，顺序不影响正确性。

## 新增一个函数

直接在 `Public\` 或 `Private\` 下新建 `.ps1`，无需改加载器（`.psm1` 从 AST 自动收集 `Public\` 里的函数名）。

## 打包

```bat
build.cmd                       :: 双击即可
build.cmd -NoPause              :: 构建后不等回车
set CI=1 && build.cmd           :: 非交互环境（不等待）
```

**发版前先改版本号**：编辑 `Modules\Winst.Core\Public\WinstConstants.ps1` 里 `Get-WinstProductVersion` 的返回值。构建只读取它，并在输出里打印它来自哪个文件，不会写回任何东西。tag 必须与它一致（`v<版本>`）。

**每次构建先清空 `dist\`**。构建树先放在临时目录，通过冒烟与压缩包校验后才落地为本次产物：

```
winst\              可以直接运行的发布树（winst.cmd / winst.ps1 / LICENSE / Modules\Winst\）
winst.zip           从临时构建树压缩得到，不含测试用 manifest.json
winst.zip.sha512    sha512sums 格式：<摘要>  winst.zip
```

发布树与压缩包来自同一棵构建树。仓库根目录的 `manifest.json` 会在打包前复制到发布树、压缩时排除，所以 `dist\winst\` 可以直接测试本地清单，但它比 zip 多这个文件。测产物**不用解压**：

```bat
dist\winst\winst.cmd -v
dist\winst\winst.cmd list --cached
```

`dist\winst\` 是构建产物，可以随时删掉，下次构建会重建。删不掉时构建会明确报「产物可能正被占用」并退出 —— 通常是正在运行的 winst 或开着 `dist\` 里文件的编辑器。

`Modules\Winst\` 是把各模块合并成的单一模块（`Winst.psd1` + `Winst.psm1`），release 只需一次 `Import-Module`，冷启动明显快于开发树逐个导入。

**改完代码只需要双击 `build.cmd`**，没有别的同步动作：

- 新增模块目录 → 构建自动发现，不用改 `winst.ps1` / `build.ps1`，也没有顺序清单要维护
- 新增函数文件 → 自动进入导出名单
- 源文件编码与换行是**开发者的责任**：缺 BOM 或用 LF 时构建直接失败并列出文件，不会替你改写（否则 5.1 读中文会静默乱码）

构建自检，任一失败即中止，不会留下半套产物：

- `Modules\` 下每个子目录都要能作为模块识别（同名 `.psd1` / `.psm1` / `Public\`）
- `Modules\` 下全部脚本与 `winst.ps1` 都是 UTF-8 with BOM + CRLF
- 合并结果能通过 5.1 语法解析（报错会指回源文件）
- 用 Windows PowerShell 5.1 在临时构建树里真跑一次 `winst.ps1 -v`，且报出的版本等于产品版本
- 包内必需 `winst.ps1` / `winst.cmd` / `LICENSE` / `Modules/Winst/Winst.psd1` / `Winst.psm1`
- 包内不能有 `manifest.json` / `README.md` / `docs\` / `build.*` / `install.ps1`，也不能有单一顶层目录

## 发布

1. 先改版本号：`Modules\Winst.Core\Public\WinstConstants.ps1` 的 `Get-WinstProductVersion`
2. `build.cmd`
3. 把 `dist\winst.zip` 与 `dist\winst.zip.sha512` 作为 release 资产上传
4. tag 用 `v<版本>`（如 `v2026.10.20`），与第 1 步的值一致

- **产物名固定、不带版本号**：`releases/latest/download/winst.zip` 指向最新 release 的同名资产，一行安装命令不随版本改动
- 软件源里的 `winst` 条目按 GitHub release 解析实际下载地址，并用条目声明的 `hashFile` 校验安装包；发布时必须同时上传 zip 与 sha512 侧车

`manifest.json` 的 `_manifestVersion` 独立于产品版本：它是软件源目录自己的版本，增删改清单条目时更新。两者不一致时构建会提示，但不阻断。

## 一行安装脚本（install.ps1）

只做三件事：下载 `winst.zip` → 解压到临时目录拿到可运行的 `winst.ps1` → 调用 `winst install winst --from <zip>`。安装逻辑全部在 `Install-WinstSelf` 里，脚本本身不含第二套实现。

通过 `irm | iex` 执行时有一些硬约束：

- 不用 `param()`：管道执行时参数传不进来
- 不用 `$PSScriptRoot` / `$PSCommandPath`：管道执行时为空
- 不用 `exit`：会杀掉调用者会话，失败时抛异常
- 不依赖任何本地文件
- `Start-Process -ArgumentList` 收到数组时只按空格拼接，不会自动加引号；`-File` 与 `--from` 的路径必须自行按 Windows 命令行规则加引号，避免含空格路径被截断

## 自检清单

改完代码至少确认（`config list` 前按需保留上面的隔离环境变量）：

```powershell
# 全部模块脚本语法（无输出即通过；用 Windows PowerShell 5.1 执行）
powershell -NoProfile -Command 'Get-ChildItem Modules -Recurse -Filter *.ps1 | ForEach-Object { $e=$null; [void][Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$null,[ref]$e); if($e){ "$($_.Name): $($e[0].Message)" } }'

# 从源码跑（开发树是多模块形态，不必先构建）
powershell -NoProfile -ExecutionPolicy Bypass -File .\winst.ps1 --version

# 帮助与配置（只读命令）
powershell -NoProfile -ExecutionPolicy Bypass -File .\winst.ps1 help
powershell -NoProfile -ExecutionPolicy Bypass -File .\winst.ps1 config list

# 打包 + 冒烟（构建自己会跑一次 -v）
build.cmd
```

涉及安装 / 卸载的改动，在上述三个目录都已隔离的环境里跑一遍 `install` → `list` → `update --check` → `uninstall`。
