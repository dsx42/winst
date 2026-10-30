﻿# 数据文件

## 位置总览

```
%USERPROFILE%\.winst\                    数据目录，可用 WINST_HOME 覆盖
├── winst.lock                           单进程锁（记录占用者 PID、启动时间和运行路径）
├── config.json                          用户配置
├── lists\                               安装清单目录（按需创建）
│   └── setup.list
└── apps\                                安装包位置（pkgDir 默认值）
    ├── winst.json                       缓存索引（整个 pkgDir 一份）
    ├── <id>\                            各软件的安装包与配套文件（扁平）
    └── manifests\
        ├── sources.json                 软件源列表
        ├── local.meta.json              本地清单的 sidecar
        ├── *.json                       本地清单
        └── remote\
            ├── <用户>__<仓库>.json       远程清单缓存
            └── <用户>__<仓库>.meta.json  元数据与逐条解析锁

<installRoot>\                           软件安装根目录，默认 %USERPROFILE%\winst
├── state.json                           安装台账
├── winst\                               winst 自身（winst.ps1 + winst.cmd + Modules\）
└── <id>\                                各软件安装目录
```

- `pkgDir` 可指向 U 盘或 NAS，安装包、源列表和清单缓存随之一同共享。
  网络共享**只支持 UNC 路径**（`\\服务器\共享名\目录`），不支持映射盘符（`Z:\...`）：映射只在当前登录会话可见，winst 以管理员身份运行时往往访问不到。
  共享需要认证时，在「设置 → 安装包位置」里先输入 UNC 路径，再按提示单独输入账号与密码（密码不回显；两者都可以直接回车跳过）。winst 调用系统凭据管理器（cmdkey）认证，**认证成功才保存路径**，账号密码本身不写进 `config.json`、也不由 winst 保存。路径里不要写账号密码。
- 更改 `installRoot` 只对此后的安装生效：已装软件留在旧位置继续可用，改完会列出旧位置里已有的软件目录。安装记录跟着安装位置存放，新位置暂时是空的。
- 新位置没有台账时，`winst repair` 会扫描安装目录、注册表和 Appx 记录来重建，进入「已装软件」也会执行修复扫描。
- winst 写出的 JSON、`.list` 和生成的文本文件使用 UTF-8 无 BOM。`Write-FileAtomic` 先写临时文件再替换；目标卷不支持原子替换时会退化为直接覆盖。写入或替换失败同样会清理临时文件；共享目录「可写不可删」或临时文件被其它进程占用导致删不掉时，`--verbose` 会给出路径（清理失败不影响写入结果，也不掩盖原始错误）。
- 同一数据目录用 `winst.lock` 的独占句柄防止并发写入。句柄决定占用状态，进程强杀后由系统释放；锁文件本身可能保留。只读的版本/帮助调用不抢锁。

## config.json

| 键 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `installRoot` | string | `%USERPROFILE%\winst` | 软件安装根目录与台账位置；环境变量/PATH 的作用域由实际安装目录是否位于 `%USERPROFILE%` 下决定 |
| `pkgDir` | string | `<数据目录>\apps` | 安装包与清单数据位置 |
| `pruneOldPackages` | bool | `true` | 新版本下载成功后删除同 id 目录中不在本次保留列表里的旧文件 |
| `manifestTTLHours` | int | `24` | 软件源及逐条版本信息的缓存有效期（小时）；不大于 0 时逐条信息视为总过期 |
| `proxy` | string | 空 | 代理地址 |
| `proxyMode` | string | `auto` | `auto` 直连失败再试代理；`always` 始终走代理；`off` 不走代理；`download-direct` 下载先直连、失败再用代理，其它请求直接走代理 |
| `updateFilesOnly` | bool | `true` | 更新已登记软件时只替换文件，不改环境变量和 PATH；已存在的快捷方式仍会校验并修正指向错误 |

- 路径支持 `%VAR%`，写入时保留原文，读取时展开；相对路径以数据目录为基准归一化。
- 布尔项接受 `开` / `关`、`on` / `off`、`true` / `false`、`yes` / `no`、`y` / `n`、`1` / `0`；无法识别的配置值不会被当作明确的 false。
- 文件缺失、损坏或缺键时按默认值运行：缺键只补该键；整份无法解析时先备份为 `config.json.bak`（同一份坏文件只留一份）并提示一次，再按默认值运行，不会静默丢弃用户原来的设置。只有表中键参与默认配置读取，未知键不会从手工配置文件并入当前上下文；保存配置时按固定键集写出。
- GitHub 通过网页通道访问，不需要令牌。

**路径解析优先级**

```
pkgDir      : --pkg-dir > WINST_PKG_DIR > 脚本同目录已存在的 apps\ > 有效 config.json > <数据目录>\apps
installRoot : --install-root > WINST_INSTALL_ROOT > 有效 config.json > %USERPROFILE%\winst
```

配置文件存在但其中的路径值为空时继续用默认路径。脚本同目录存在 `apps\` 即优先作为包目录，这正是离线套装的零配置入口；可用参数或环境变量显式覆盖。

## state.json（安装台账）

位置 `<installRoot>\state.json`。

```jsonc
{
  "schemaVersion": 2,
  "installed": {
    "jdk21": {
      "version": "21.0.5",
      "type": "portable",
      "group": "JDK",
      "installDir": "D:\\Apps\\jdk21",
      "installedAt": "2026-09-07T10:00:00",
      "updatedAt": "2026-09-07T10:00:00",
      "manifestOrigin": "dsx42/winst-manifest",
      "managed": "winst",
      "appliedEnv": [ { "name": "JAVA_HOME", "scope": "Machine" } ],
      "appliedPath": [ { "path": "D:\\Apps\\jdk21\\bin", "scope": "Machine" } ],
      "appliedShortcuts": [ "C:\\Users\\me\\Desktop\\Eclipse Temurin JDK 21.lnk" ],
      "appliedFiles": [ "colors\\Alabaster.icls" ],
      "oldVersions": [ { "version": "21.0.4", "detail": "系统安装记录: Microsoft Windows Desktop Runtime 21.0.4 (x64)", "recordKey": "Microsoft.PowerShell.Core\\Registry::HKEY_LOCAL_MACHINE\\SOFTWARE\\...\\Uninstall\\{...}" } ],
      "uninstall": {
        "method": "portable-dir",
        "removeEnv": [ "JAVA_HOME" ],
        "removePaths": [ "%JAVA_HOME%\\bin" ],
        "commands": [],
        "uninstallArgs": "",
        "nameRule": "",
        "shortcutName": ""
      }
    }
  }
}
```

要点：

- `schemaVersion` 当前为 `2`。读取时一律归一化（与 `schemaVersion` 取值无关）：字符串形式的 `appliedEnv` / `appliedPath` 转为带 `scope` 的对象，字符串项按 `User` 处理；需要保存时由后续流程落盘。高于当前版本则拒绝继续，提示升级 winst。
- JSON 无法解析时，先备份为 `state.json.bak-<时间戳>`，再在内存中重建空台账。备份失败会返回错误并停止写入，避免覆盖唯一副本；成功备份后的重建由后续保存落盘。
- `installedAt` 是首次安装时间，`updatedAt` 是最近一次通过条目级接口写入该记录的时间。修复扫描的整份合并保存不经过该接口，不会统一重写这两个时间戳。
- `applied*` 记录 winst 管理的系统项与配套文件位置，供更新和卸载回收；`managed` 为 `winst` 或 `external`。外部登记的 `applied*` 与卸载快照为空，卸载时仍可能使用当前清单的定义。
- `uninstall` 保存安装时的卸载操作；源条目删除或修改后，已登记软件仍可使用快照。`nameRule` 可以是字符串或字符串数组。
- `oldVersions` 记录本机与 `version` 并存的低版本：条目为 `{ version; detail; recordKey }`，`recordKey` 是该版本在系统安装记录里的卸载键路径，挑的是**卸载器当前可用**的那条（同一版本常同时有外层引导包与内层 MSI 两条记录）。只有能区分多个版本的检测方式（`registry` / `fileVersion` / `markerFile` / `jsonFile`）才可能产生条目，且只收「同一产品」的旧版本（`appx` 只取最高版本，不把运行时家族的其它包记为旧版本）。每次修复扫描或安装后的版本检测都会重写这个字段，清掉已经不存在的版本。
- `installed` 的 id 使用 Ordinal 比较。写入会移除与目标 id 仅大小写不同的旧键，避免产生 PowerShell 无法解析的重复 JSON 属性。
- `download` 类型不写安装台账。

### 条目级写入与读缓存

安装、更新、引擎和 winst 自身记录、外部登记都通过 `Save-WinstInstalledAppEntry`：重读最新台账，只覆盖目标 id，沿用已有 `installedAt`，写入当前 `updatedAt`，最后整份原子落盘。这样可避免安装流程开始时的旧快照覆盖嵌套引擎或自更新流程刚写入的记录。修复扫描和卸载删除有各自的整份合并流程。

`Read-WinstState` 按路径和文件戳（最后写入时间、长度）缓存解析并归一化后的台账：

- 命中时仍先 stat，再返回 `Copy-WinstState` 的副本；外层字典和每个条目是新建对象，条目内数组及 `uninstall` 等嵌套对象按引用共享。
- 因而不是深拷贝：写台账要整条替换（`Set-WinstInstalledApp`），不能就地修改 `appliedEnv` 或 `uninstall` 的元素，否则会污染缓存。
- `Save-WinstState` 落盘后先失效相关系统缓存，再用刚写入的内容和新文件戳刷新台账缓存，因此随后读取能看到已落盘内容；外部改动通过文件戳失效。

## winst.json（缓存索引）

位置 `<pkgDir>\winst.json`，与各 id 目录同级。

```jsonc
{
  "jdk21": {
    "version": "21.0.5",
    "files": [ "OpenJDK21U-jdk_x64_windows_hotspot_21.0.5_11.zip" ],
    "hashes": { "OpenJDK21U-....zip": "<sha256>" },
    "manifestHashes": { "<文件>": { "sha512": "<值>" } },
    "downloadedAt": "2026-09-07T09:00:00",
    "fileMeta": {
      "Alabaster.icls": {
        "url": "https://raw.githubusercontent.com/...",
        "sourceVersion": "2026.2.3",
        "etag": "\"9a1f3c\"",
        "lastModified": "Tue, 02 Sep 2026 03:11:07 GMT",
        "size": 18234,
        "downloadedAt": "2026-09-07T09:00:04",
        "lastCheckedAt": "2026-09-07T09:00:04",
        "expectedHash": "",
        "expectedAlgorithm": "",
        "checksumHashFile": "",
        "checksumHashFrom": "",
        "checksumFingerprint": ""
      }
    }
  }
}
```

- `hashes` 保存各文件实测 sha256；`manifestHashes` 保存软件源声明算法对应的摘要。有声明校验时，优先用索引中的同算法摘要判断缓存，缺失记录才现算；这不代表所有同版本缓存都能跳过版本、地址或新鲜度检查。
- `fileMeta` 记录实际 URL、文件自身版本、HTTP 校验器、大小、下载与检查时间，以及期望摘要和校验文件声明。它同时用于新鲜度判断、声明变更检测和严格离线校验；切换 `hash` / `hashFile` 时来源字段必须成组更新。
- 索引在进程内按文件戳缓存，命中后仍逐 id 检查目录是否存在。`Save-WinstCacheIndex` 只做整份写入（经 `Write-FileAtomic`，并失效 JSON 缓存）；包索引由 `Update-WinstPackageCacheIndex` 写回前先重读，只替换当前 id，保留嵌套流程写入的其它条目。
- 整份索引缺失或损坏时按目录重建：版本和摘要留空，`downloadedAt` 取文件时间；已存在的损坏文件先尝试备份为 `winst.json.bak`。单条记录无法归一化时只重建该条且不立即整份回写，避免误伤原文中的其它记录。
- 索引中目录已不存在的条目会从内存结果剔除，`Changed` 为真时由修复或后续写入落盘。`winst repair` 会校对并保存必要的索引修复，但不删除安装包。
- 原子替换不解决多机同时整份写入的丢更新问题；同时写同一索引时后完成者覆盖。日常运行由数据目录单进程锁约束，多机共享仍需避免并发写。

## 清单文件（.list）

安装清单是 UTF-8 行式文本，默认位于 `<数据目录>\lists\setup.list`。

```text
# 重装系统后要装的软件
jdk21
idea
vscode==1.96.0
```

- 空行忽略，`#` 开头为注释；保存时注释集中写在文件开头，随后按条目顺序写回，不能保留原始行位置。
- 每行是 `id` 或 `id==版本`；行尾没有单独的注释语法，示例中的注释必须独立成行。同一 id 只保留第一次出现，比较区分大小写；非法 id 行记为坏行，保存时会丢弃，调用方负责提示。
- 清单只写用户显式选择的条目，依赖不自动写入。
- `id==版本` 用于声明期望版本；菜单安装遇到与当前源版本不一致时会要求选择按源版本安装或跳过，CLI 会提示不一致并继续按源版本安装。源里没有可用版本时跳过，不静默猜测版本。
- 通过清单管理功能输入的显式路径也必须位于 `<数据目录>\lists\` 下，并统一使用 `.list` 后缀，防止任意路径写入。

## manifests/sources.json

```jsonc
{
  "_version": 1,
  "sources": [
    { "repo": "dsx42/winst-manifest", "url": "https://raw.githubusercontent.com/dsx42/winst-manifest/main/manifest.json" },
    { "repo": "owner/repo", "url": "https://raw.githubusercontent.com/owner/repo/HEAD/manifest.json" }
  ]
}
```

读取时也接受每项的 `name` 作为 `repo`，或直接用数组作为源列表；写出统一为上述结构。本地源 `local` 不记录在此。

内置源 `dsx42/winst-manifest` 始终由 `Ensure-OfficialManifest` 维护：缺失时补到首位，地址偏离时恢复，不在首位时挪回首位。内置源仓库只分发 `manifest.json`，软件包来自条目声明的地址，不依赖该仓库的 release。

## manifests/remote/*.meta.json（sidecar 与解析锁）

```jsonc
{
  "url": "https://raw.githubusercontent.com/dsx42/winst-manifest/main/manifest.json",
  "version": "2026.10.20",
  "fetchedAt": "2026-10-20T16:49:00",
  "resolvedAt": "2026-10-20T16:49:12",
  "apps": [ /* 每个条目的完整解析结果 */ ]
}
```

`apps` 是安装计划的持久化快照，典型结构如下（字段随类型与来源而异）：

```jsonc
{
  "id": "jdk21",
  "name": "Eclipse Temurin JDK 21",
  "description": "Java 开发工具包",
  "type": "portable",
  "version": "21.0.5+11",
  "group": "JDK",
  "dependencies": [],
  "processes": [],
  "manifestOrigin": "dsx42/winst-manifest",
  "resolvedAt": "2026-10-20T16:49:12",
  "versionFromPackage": false,
  "sourceVersion": "jdk-21.0.5+11",
  "sourceVersionRewrite": [ { "pattern": "^jdk-", "replace": "" } ],
  "remoteFresh": "unchanged",
  "ok": true,
  "error": "",
  "notes": [],
  "download": {
    "kind": "github",
    "repo": "...",
    "tag": "jdk-21.0.5+11",
    "files": [ { "url": "...", "name": "...", "dest": "", "hash": "", "hashFile": "", "hashFrom": "" } ]
  },
  "install": { "method": "portable", "stripTopDir": true, "portableMode": "clean", "keep": [], "mainExe": "bin\\java.exe" },
  "postInstallCopy": [],
  "env": { "JAVA_HOME": "{installDir}" },
  "addToPath": [ "{installDir}\\bin" ],
  "shortcuts": { "desktop": false, "startMenu": false },
  "postInstall": [],
  "detect": { "method": "fileVersion", "file": "bin\\java.exe" },
  "uninstall": { "method": "portable-dir", "removeEnv": [], "removePaths": [] }
}
```

- 顶层 `fetchedAt` 是本次取得或复用清单的时间，每次成功刷新都会改写；顶层 `resolvedAt` 是本次 sidecar 写入时间。每条 `resolvedAt` 用于 `manifestTTLHours` 的按需刷新判断，保留上次成功结果时也会更新为本次尝试时间。
- `version` 已应用版本改写，`sourceVersion` 保留上游值；`sourceVersionRewrite` 供后续包内派生版本使用。`remoteFresh` 只在版本取自主包文件信息的条目中有意义，取 `changed` / `unchanged` / `unknown`，记录刷新时远端与缓存校验器的比对结论；成功下载后可更新为 `unchanged`。
- 单条失败写 `ok: false` 与 `error`，不影响其它条目。若该 id 上次成功，刷新会保留上次成功计划、追加失败备注并更新本条 `resolvedAt`；清单中删去的 id 会清退。
- 按需刷新只解析传入的 id，未解析过的条目不会写进 `apps`；关键字搜索零命中时会按清单正文补找并解析这些条目（见 `docs\manifest.md` 的「源刷新与解析锁」）。
- 刷新解析成功但持久化失败时，本会话保留最新解析结果供搜索 / 安装使用，提示尚未写盘；后续成功写入会清除此会话覆盖。退出进程后只能使用磁盘上已有的数据。
- 远程清单正文与 sidecar 分开：正文缓存用于离线回退，sidecar 保存 URL、时间和解析锁。sidecar 缺失或损坏时返回空结果，不删除正文缓存。
- 本地清单没有 `remote\` 正文缓存，但仍将解析锁写入 `<pkgDir>\manifests\local.meta.json`。本地正文按以下优先级合并：脚本同目录 `manifest.json`、脚本同目录 `manifests\*.json`、`<pkgDir>\manifests\*.json`；同 id 取先出现者。包目录下的 `*.meta.json` 与 `sources.json` 不当正文读取，任一本地正文解析失败则本地源整体失败。

## U 盘离线套装

`winst bundle pack <清单> <目标目录> [--skip-missing]` 生成的结构：

```
E:\winst-kit\
├── winst.cmd                 双击启动器（进入交互菜单）
├── winst.ps1
├── LICENSE
├── Modules\                  当前运行副本的模块目录
├── manifest.json             脚本同目录存在时复制
├── manifests\                脚本同目录存在时复制
├── apps\                     安装包 + winst.json + manifests\
└── lists\                    仅本次选中的清单
```

- 收集清单条目及其传递依赖，并显式加入 FluxDown-CLI 与 7-Zip-CLI；依赖解析失败的项目不会由打包器猜测补全。
- 缺包检查先看本地缓存。交互模式可询问是否联网补齐；`--skip-missing`、`--offline`、`--dry-run` 或非交互且未指定 `--yes` 时不下载。补齐后重读目录、缓存索引与条目视图，重建复制计划，仍缺包的条目跳过；目标机安装这些条目时可能需要联网。
- `apps\manifests\` 复制源列表、远程缓存和 sidecar；脚本同目录的本地清单另外复制。索引保留目标已有的无关条目，但本次相关条目的摘要与 `fileMeta` 以来源缓存为准。
- 目标同版本且本次文件齐全时跳过；版本不同或记录无法证明同版本时，先安全清理该 id 的旧目录再复制，避免新旧文件混合。只动本次涉及的 id 目录，不清空其它软件。
- `winst.cmd` 由打包流程生成，模块和本地清单来自当前运行副本，而不是重新下载 release。目标机直接运行时，脚本同目录 `apps\` 自动成为包目录；离线安装仍要求所需正文、解析锁、安装包及可验证的校验信息齐全。

套件重复制作时整棵替换 `Modules`，避免残留旧模块或形成 `Modules\Modules`。任何待复制安装包失败都会使打包命令返回失败；已经复制的内容会保留，可修复原因后重试。
