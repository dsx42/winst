# 软件源与清单

本文是第三方编写软件源的完整参考：字段、枚举取值与约束对应 winst 的实际解析逻辑，写错时 `manifest` 刷新 / 安装会给出明确报错。

## 软件源

winst 自身不含任何软件定义，全部条目来自软件源。三类来源，**彼此独立、互不覆盖**：同一 id 出现在多个源时都会显示，安装 / 更新时由用户选择（或 `--source` 指定）。

| 来源 | 名称 | 位置 | 配置 |
|---|---|---|---|
| 本地清单 | `local` | 脚本同目录 `manifest.json`、脚本同目录 `manifests\*.json`、`<pkgDir>\manifests\*.json` | 不需要，自动识别 |
| 内置源 | `dsx42/winst-manifest` | 独立的清单仓库，固定 `raw.githubusercontent.com` 地址，该仓库没有 release | 自动就位，不可删除 |
| 自定义源 | `用户名/仓库` | `manifest add` 添加，列表存在 `<pkgDir>\manifests\sources.json` | 需显式添加 |

- 只支持 GitHub 仓库源。`manifest add` 接受 `用户名/仓库`、仓库页地址、清单 raw 地址
- 添加时用真实请求校验（仓库不存在 / 没有 `manifest.json` / 内容非法都会明确报错，不写入源列表）
- 源列表与清单缓存都存在 `<pkgDir>\manifests\` 下：多台机器共用同一 `pkgDir` 时，源配置一并共享

## 清单文件格式

标准格式是 catalog 包裹结构：

```jsonc
{
  "_manifestVersion": "2026.10.20",
  "apps": [ { "id": "..." }, ... ]
}
```

本地清单额外兼容两种便于手写的宽松格式，加载时自动归一化：顶层数组 `[ {...} ]`、顶层单条目对象（含 `id`）。

- **纯 JSON**：清单文件不写注释，示例里的 `//` 只用于文档说明
- **编码**：UTF-8（带不带 BOM 均可）；其它编码会导致解析失败并明确报错
- winst 自己写出的文件（清单缓存、`bundle pack` 复制的清单、`.list`）一律 UTF-8 无 BOM
- `_manifestVersion` 只用于人看与排错，winst 不按它做兼容分支；改内置清单时要一起更新

## 条目结构

```jsonc
{
  "id": "jdk21",                        // 唯一标识，同时是目录名
  "name": "Eclipse Temurin JDK 21",
  "description": "Java 开发工具包",      // 参与 search 关键字匹配
  "type": "portable",                   // portable | installer | file | download
  "group": "JDK",                       // 展示分组
  "dependencies": [ "jdk25" ],          // 依赖的软件 id

  "source": {
    "kind": "github",                   // direct | github | listing | page | json | magnet
    "repo": "adoptium/temurin21-binaries",
    "files": [
      { "file": "OpenJDK21U-jdk_x64_windows_hotspot_*.zip" }
    ],
    "versionRewrite": { "stripPrefix": "jdk-" }
  },

  // portable 的安装与主程序字段；addToPath 以下三项 portable / file 共用
  "stripTopDir": true,
  "portableMode": "clean",              // clean（先删后解压，保留 keep）| overwrite
  "keep": [ "config\\" ],
  "mainExe": "bin\\java.exe",
  "extractFiles": [],
  "addToPath": [ "%JAVA_HOME%\\bin" ],
  "env": { "JAVA_HOME": "{installDir}" },
  "shortcuts": { "desktop": false, "startMenu": false },
  "postInstallCopy": [ { "from": "a.exe", "to": "b.exe", "move": true } ],
  "postInstall": [ { "exe": "python.exe", "args": "-m pip install -U pip", "timeoutSec": 600 } ],

  // installer 专属
  "installArgs": "/S",
  "uninstallArgs": "/S",
  "installerExe": "",                   // 主包本身是压缩包时，解压后要运行的安装程序

  "processes": [ "chrome.exe" ],        // 进程占用检测兜底
  "uninstall": { "commands": [], "name": "" },

  "detect": { "method": "fileVersion", "pathGlob": "{installDir}\\bin\\java.exe" }
}
```

## 条目字段

| 字段 | 默认值 | 说明 |
|---|---|---|
| `id` | 必填 | 单层目录名，**区分大小写**；不能为空、`.` / `..`、首尾空白、尾点、控制字符、Windows 文件名非法字符、保留设备名或超过 100 字符。绿色版安装目录 = `<installRoot>\<id>`，包目录 = `<pkgDir>\<id>` |
| `name` | `= id` | 显示名；`installer` 未声明 `detect.name` 时也用它生成注册表匹配规则 |
| `description` | 空 | 一句话说明，参与 `search` 的关键字匹配 |
| `type` | 必填 | 见下方「条目类型」 |
| `group` | 空 | 展示分组，列表里同组聚拢并打分组标题；不参与版本比较与安装流程 |
| `dependencies` | `[]` | 依赖 id 列表；安装 / 更新前先处理「未装 / 可更新」的依赖；卸载时提示但不拦截；`download` 条目不参与 |
| `version` | 空 | 来源取不到版本时的兜底；也供 `{version}` / `{versionMajor}` 展开。各来源何时必填见「六种下载来源」 |
| `source` | 必填 | 下载来源定义，见「六种下载来源」 |
| `stripTopDir` | `true` | `portable` 的主包解压规则，或 `installer` 声明 `installerExe` 时的外层包解压规则。`true` 剥掉唯一顶层目录；`false` 原样解压；字符串 = 只取包内该路径（目录取内容、文件取自身；该文件本身是压缩包则再解压一层）；路径不存在即报错 |
| `extractFiles` | `[]` | 仅 `portable`：只取包内这几个路径；声明后不再看 `stripTopDir`；任一不存在即报错 |
| `portableMode` | `clean` | 仅 `portable`：`clean` 先删后解压（保留 `keep`），`overwrite` 直接覆盖；空值及无法识别的值按 `clean` |
| `keep` | `[]` | 仅 `portable` 的 `clean` 模式：相对安装目录的保留路径通配；支持 `*`（单层）/ `**`（跨层）/ `?`，不写分隔符时按文件名匹配（任意层都保留）；`overwrite` 模式不使用 |
| `mainExe` | 空 | 仅 `portable`：主程序相对路径（快捷方式目标、进程检测、`cliVersion` 入口）；`file` 的主程序自动取主包落位文件 |
| `addToPath` | `[]` | `portable` / `file` 加入 PATH 的路径；布尔 `true` 或字符串 `"true"` 表示安装目录本身；字符串 `"false"` / `"0"` / `"no"` / `"off"` 会被忽略 |
| `env` | `{}` | `portable` / `file` 的环境变量；`{installDir}` 展开为实际安装目录，`%VAR%` 原样写入；作用域按安装目录自动判定（`%USERPROFILE%` 下 → User，否则 Machine） |
| `shortcuts` | 均为 `false` | `portable` / `file` 的 `desktop` / `startMenu`，目标为主程序；主程序是 `.ps1` 时自动生成同名 `.cmd` 启动器 |
| `postInstallCopy` | `[]` | `portable` / `file`：安装目录内复制 / 改名（`move: true` 为移动），`from` / `to` 均为相对路径，`from` 支持 `*` / `?` 通配；缺一项的规则跳过；`from` 无命中或命中多个即报错 |
| `postInstall` | `[]` | `portable` / `file`：安装末尾执行的命令，非零退出视为安装失败；字段见下方「命令条目」 |
| `installArgs` | 空 | 仅 `installer`：静默安装参数；应用包安装不使用它；含未闭合双引号或控制字符时清单报错 |
| `uninstallArgs` | 空 | 仅 `installer`：追加到注册表官方卸载命令后的参数；应用包卸载不使用它 |
| `installerExe` | 空 | 仅 `installer`：主包是压缩包时，先解压再运行包内这个安装程序（支持 `{version}` 与 `*` / `?`）；无命中或命中多个即报错；声明它时 `stripTopDir` 表示外层包的解压规则 |
| `processes` | `[]` | 进程名列表，见表后的「进程占用检测」；`download` 不安装，无需声明 |
| `uninstall` | 空 | 卸载定义，见「卸载定义」；`download` 不使用 |
| `detect` | 未写整个 `detect` 时，`installer` → `registry`，其余 → `none`；写了对象但没写 `method` 时一律 → `none` | 已装版本检测，见「版本检测」；`download` 强制为 `none` |

**不同类型忽略的字段**：

- `installer` 忽略 `stripTopDir`（除非声明了 `installerExe`）、`portableMode`、`keep`、`mainExe`、`addToPath`、`env`、`shortcuts`、`postInstallCopy`、`postInstall` —— 安装位置与系统设置都由安装程序自己管理。写了会记一条提示，不会静默生效。
- `download` 只保留下载来源与公共元数据；忽略全部安装、进程检测、系统设置、版本检测和卸载字段（`processes` / `stripTopDir` / `extractFiles` / `portableMode` / `keep` / `mainExe` / `addToPath` / `env` / `shortcuts` / `postInstallCopy` / `postInstall` / `installArgs` / `uninstallArgs` / `installerExe` / `detect` / `uninstall`）。
- `file` 忽略 `stripTopDir`、`extractFiles`、`portableMode`、`keep` 和 `mainExe`。主程序 = 主包落位文件；`postInstallCopy` 中与主包文件名完全一致的 `from` 且 `move: true` 时，取该规则的 `to` 文件名作为改名结果。

### 进程占用检测

`processes` 写可执行文件名（通常含 `.exe`），匹配时去掉扩展名且不区分大小写；空项不产生匹配。它补充安装目录归属检测，主要用于 `installer` 无法从系统记录解析安装目录的情况；`portable` / `file` 也可声明：

1. 先按可执行文件路径是否位于该软件安装目录判定；路径确认的进程可在用户选择结束后自动结束。
2. 未被路径命中时，再按 `processes` 声明的名字匹配。名字与该条目的主程序相同，视为可确认归属；`installer` 没有 `mainExe`，所以仅按名字命中的进程不会被自动结束。
3. 仅按名字命中但不能确认归属的进程会列出并要求用户手动关闭；`--kill` 和交互式“结束进程”都不会自动结束它们，以避免误杀同名或共享运行时进程。
4. 路径不可见且未命中 `processes` 时，只有进程名与主程序相同才会作为候选，且不属于可自动结束的一组。

## 条目类型

| `type` | 安装动作 | 卸载动作 | 说明 |
|---|---|---|---|
| `portable` | 解压主包到 `<installRoot>\<id>`，按 `portableMode` / `keep` / `stripTopDir` / `extractFiles` 落地 | `portable-dir`（删目录 + 回收系统项） | 绝大多数绿色版软件 |
| `installer` | 运行安装程序；主包是 `.msix` / `.msixbundle` / `.appx` / `.appxbundle` 时改用 `Add-AppxPackage` | `registry`（跑官方卸载器）；应用包为 `appx` | 安装位置由安装程序决定，安装后回读系统记录 |
| `file` | 把主包复制到 `<installRoot>\<id>`（临时文件 + 原子替换） | `portable-dir` | 单文件绿色版（`.exe` / `.ps1` / `.jar` 等，与格式无关） |
| `download` | 只把包存到 `<pkgDir>\<id>`，不安装、不写台账 | 不适用（用 `clean` 删包） | 「仅下载软件包」类条目 |

`exe` 与 `file` 同义；读取时统一归一化为 `file`。

## 六种下载来源

`source.kind` 必填，大小写不敏感。`source.files[]` 第一项是主包，后续项是配套文件；每项可写对象，或写字符串作为 `url` 简写。也可省略 `files`，直接写 `source.url` 表示唯一主包；`files` 非空时忽略 `source.url`。page 源不能靠 `source.url` 提供主包地址，因为它只接受页面提取；json 源不能用字符串简写替代主包 `urlKey`。`skipExistsCheck` 默认 `false`，对 direct / github / listing / page / json 有效；magnet 不做 HTTP 地址探测。

| kind | 用途 | `versionFrom` 可用值 |
|---|---|---|
| `direct` | 固定地址或带 `{version}` 的地址模板 | `page`（官网页面实时取）、`package`（下载后读文件信息）；**也可完全不写 `versionFrom`**，改用条目 `version`；条目 `version` 非空时优先于 `versionFrom` |
| `github` | GitHub Releases（走网页通道，不用 API） | `tag`（默认，发布 tag）、`file`（下载文件名）、`package`、`releaseTitle`（发布标题）、`releaseBody`（发布正文） |
| `listing` | 版本 / 目录列表页 | 不读 `versionFrom`——版本由列表页候选 + `versionKind` 决定 |
| `page` | 下载详情页，按元素定位下载按钮 | `url`（默认，从下载地址识别）、`page`（从页面内容识别）、`package` |
| `json` | 下载信息只在接口里的站点 | 不读 `versionFrom`——用 `versionKey`，或 `versionKind` / `versionBetween` 从下载地址识别 |
| `magnet` | 磁力链接（BitTorrent），交给 `FluxDown-CLI` 取包 | 不读 `versionFrom`——用 `versionKind` / `versionBetween` 从文件名 `dn` 识别 |

`versionFrom` 写错取值会直接报错并列出可用值，不会静默回落。

**GitHub 走网页通道**：GitHub API 的匿名配额按出口 IP 计（同一 NAT 多机共享 60 次/小时）且常被企业网络拦截，因此 winst 只读 `releases/latest` 跳转、`releases` 列表页、`releases/expanded_assets/<tag>`、`releases/download/<tag>/<文件>`，不消耗配额、不需要令牌。发布列表（tag / 标题 / 正文 / 预发布标记）统一取自 `releases` 列表页，见下文 github 源。

### direct 源

```jsonc
"source": {
  "kind": "direct",
  "versionFrom": "page",                        // 可选：page | package；不写则用条目 version
  "pageUrl": "https://example.com/download",    // versionFrom: page 时必填
  "versionKind": "semver",                      // 可选：从版本页识别版本
  "versionBetween": [ "Version ", " " ],        // 可选：与 versionKind 二选一或搭配
  "files": [
    { "url": "https://example.com/app-{version}.zip" }
  ]
}
```

- 条目 `version` 非空时直接使用，不再读取 `versionFrom` / `pageUrl`；为空时，`versionFrom: "page"` 从页面取版本，`"package"` 等取包，未写 `versionFrom` 会报缺少版本号。
- `versionFrom` 只接受 `page` / `package`；写别的值会报错。`page` 必须配 `pageUrl` 以及 `versionKind` / `versionBetween` 至少一项，无法识别即报错；`fetchWith` 可选 `iwr`（默认）/ `browser`。
- `source.packageVersion` 只能配合 `versionFrom: "package"`，写法见「包内版本派生」。
- 每个文件都必须写完整地址 `url`；只写文件名通配 `file` 无法定位。地址中的 `{version}` / `{versionMajor}` 无法展开为版本时即报错。
- 刷新时会探测主包地址一次；`404` / `410` 判为条目解析失败。

### github 源

```jsonc
"source": {
  "kind": "github",
  "repo": "ip7z/7zip",
  "releaseTag": "cli-v",              // 可选：只取该前缀的发布（含预发布），前缀会从版本号里去掉
  "versionFrom": "file",              // 可选：tag（默认）| file | package | releaseTitle | releaseBody
  "versionKind": "semver",            // file 必填其一；releaseTitle / releaseBody 可再配它
  "versionBetween": [ "v", " " ],     // file 必填其一；releaseTitle / releaseBody 必填
  "skipExistsCheck": false,           // 可选：关掉地址 HEAD 可用性校验
  "latestOnly": false,                // 可选：true = 最新发布里没有所需文件时直接报错，不回退旧发布
  "files": [
    { "file": "7z*-x64.exe" }         // 文件名通配：需读该发布的文件列表
  ]
}
```

`source.repo` 必填，`source.files` 至少一项。`files[]` 的定位方式二选一：

- `url` 可写完整地址，也可只写文件名（如 `"rufus-{version}.exe"`）→ 自动补全 `releases/download/<tag>/<文件名>`；逐个探测地址可用性
- `file` 通配或 `re:` 正则 → 读该发布的资产列表再匹配；无命中即报错，多命中取第一个并提示

**最新发布里没有所需文件时退回更早的发布。** GitHub 上常见「release 已建好、资产还在分批上传」：这时 `releases/latest` 指向的发布里还没有安装包，但上一次发布的文件是可用的。判定为「这个发布里没有要的文件」后，逐个试更早的发布，用第一个确实含有该文件的发布（最多查最近 5 个），并在结果的 `notes` 里写明「最新发布 x 里还没有这个文件，已改用更早的发布 y」。

候选与排序规则（都用网页通道，不消耗 API 配额）：

- **候选来自 `releases` 列表页**（前 2 页）。这是发布信息的唯一来源：tag、标题、正文、`Pre-release` 标记都在这一页上；不用 `releases.atom`——它只含最近约 10 条，而且与真实发布列表可能完全脱节（adoptium 的 temurin21/temurin25 feed 里是 2023 年的 nightly beta，近期正式版一条都没有）
- **按版本号从高到低排，不按页面顺序**。列表页是 GitHub 的展示顺序（temurin21 页面上 `21.0.9+10` 排在 `21.0.13+9` 前面），按页面顺序回退会取到错误的「次新版本」
- `+build` 不参与排序：JEP 223 里 `25+36` 是「feature 25 / build 36」，等价于 `25.0.0`；否则 `25+36` 会排在 `25.0.5` 之后
- 只保留版本**严格低于**最新发布的候选；解析不出版本号的 nightly（`jdk25u-2026-02-02-15-22-beta`）排在最后

触发条件只有两种，都属于「这个发布里没有该文件」而非配置错误：

- `file` 通配在该发布的资产列表里一个都没命中，或该发布还没上传任何资产
- `files[].url` **只写了文件名**（地址由 winst 拼成）且探测到 404

清单自己写了完整地址模板时（如 `https://…/download/v{version}/x.exe`）404 仍按配置错误直接报错，不退回旧版本——那通常意味着模板写错，静默安装旧版只会掩盖问题。`latestOnly: true` 可关闭整个回退逻辑。

`versionFrom` 的取值与约束：

| 取值 | 版本来自 | 约束 |
|---|---|---|
| `tag`（默认） | 发布 tag | 不能同时写 `versionKind` / `versionBetween`（那两个是从文件名识别版本的写法） |
| `file` | 下载文件名 | 必须写 `versionKind` 或 `versionBetween` 之一，否则报错 |
| `package` | 主包下载后读文件信息 | 不能写 `versionKind` / `versionBetween` |
| `releaseTitle` | 发布标题 | 必须写 `versionBetween` |
| `releaseBody` | 发布正文 | 必须写 `versionBetween` |

`releaseTag` 是 **tag 前缀**，用于把候选限定在该前缀的发布里（含预发布；在这些发布里按版本号取最高），适合一个仓库用不同前缀发布多条产品线的情况。前缀在生成版本号时会被去掉（`cli-v1.2.3` + 前缀 `cli-v` → 版本 `1.2.3`），因此 `{version}` 可直接用在 URL 模板里。不写则用 GitHub 自己认定的 `releases/latest`。

### listing 源

```jsonc
"source": {
  "kind": "listing",
  "indexUrl": [ "https://dlcdn.apache.org/maven/maven-3/" ],   // 可为数组，多个页面的候选合并
  "versionKind": "semver",             // 必填：semver | date | digits
  "versionFilter": "3.*",              // 可选：候选版本过滤（通配或 re: 正则）
  "sort": "semver",                    // 可选：semver（默认）| text
  "skipExistsCheck": false,            // 可选：不逐个探测地址可用性
  "files": [
    { "url": "https://dlcdn.apache.org/maven/maven-3/{version}/binaries/apache-maven-{version}-bin.zip" }
  ]
}
```

`source.indexUrl` 必填，可写字符串或字符串数组；`versionKind` 必填。取列表页 → 收集全部版本候选 → `versionFilter` 过滤 → `sort` 排序 → **从高到低逐个探测地址可用性**（上限 8 个候选），第一个非 404 的即采用；探测失败会记提示并采用该候选。`sort: "text"` 使用序号字符串比较，其它取值按 `semver`。只接受 `url` 地址模板，主包模板必须能展开出版本。

### page 源

```jsonc
"source": {
  "kind": "page",
  "pageUrl": "https://www.microsoft.com/en-us/download/details.aspx?id=49117",
  "link": { "class": "dlcdetail__download-btn" },   // class / id / text（子串）/ href（通配）
  "files": [ { "file": "*.exe" } ],                  // 可选：在候选链接里挑一个
  "versionKey": "version",                           // 可选：版本在页面哪个字段
  "versionFrom": "url",                              // 可选：url（默认）| page | package
  "versionKind": "semver",                           // 可选：与 versionBetween 搭配
  "versionBetween": [ "Build ", " " ],
  "fetchWith": "browser"                             // 可选：iwr（默认）| browser（Edge 无头）
}
```

取址方式 `link` 与 `click` **二选一**（同时写会报错）：

| 字段 | 用途 | 约束 |
|---|---|---|
| `link` | 静态 HTML 里定位 `<a>`（相对地址按 `pageUrl` 解析为绝对地址） | 至少写一个条件（`class` / `id` / `text` / `href`）；空规则会命中第一个链接，因此被拒绝 |
| `click` | 下载地址由点击时的页面脚本生成时用；写法为步骤数组 | 必须配 `fetchWith: "browser"`；每一步至少要一个条件 |
| `thenLink` | `link` 命中的是网页（中转页）时，再抓一层定位真实地址 | 必须搭配 `link`；不能与 `thenClick` 同用；需要 `thenLink.link`（中转页上的定位规则，至少写一个条件）或 `files[0].file`；显式写了空的 `thenLink.link` 时即使有 `files[0].file` 也会被拒绝 |
| `thenClick` | `link` 命中中转页后还要在浏览器里点按钮取址 | 必须搭配 `link`；不能与 `click` 同用；步骤数组每一步至少要一个条件 |

`link` / `thenLink.link` / `click` / `thenClick` 的条件键只有 `class`、`id`、`text`、`href`。`class` / `id` / `text` 都是不区分大小写的子串匹配，`href` 是通配或 `re:` 正则；同一步写多个条件时必须全部满足。`source.link` 与 `thenLink.link` 的空对象 `{}`、所有条件都为空字符串，都会报 `source.link 至少要写一个条件` 或 `source.thenLink.link 至少要写一个条件`；`click` / `thenClick` 的任一步为空也同样报错。`click` 与 `thenClick` 实际执行都使用无头浏览器；`thenClick` 不必再单独声明 `fetchWith: "browser"`，但该值仍决定初始下载页和中转页的抓取方式。

`link` 在下载页无命中时会检查 iframe；候选项经过 `files[0].file` 过滤后取第一个。使用 `thenLink` 时，若声明 `thenLink.link`，最终地址只由它筛选，`files[0].file` 不再参与第二次筛选；未声明 `thenLink.link` 时才用 `files[0].file` 过滤中转页全部链接并取第一个。

`versionFrom` 取值与优先级：

1. `versionKey`（页面数据里的字段名）—— 声明后优先用它，不再看下面几项
2. `versionFrom: "page"` → 在页面 HTML 里按 `versionKind` / `versionBetween` 识别
3. `versionFrom: "url"`（默认）→ 在命中的下载地址里识别
4. 未写 `versionKind` / `versionBetween` 时回退条目 `version`；写了识别规则但匹配失败则报错
5. `versionFrom: "package"` → 页面 / 地址都不找版本，等主包下载后取；此时不能再写 `versionKey` / `versionKind` / `versionBetween`

`source.pageUrl` 必填。`files[0]` 是主包（只用于「挑哪一个」与校验）；第 2 条起是配套文件，写成带 `{version}` 的 `url` + `dest`。主包不能写 `url`（地址由页面提取），只能写 `file` 通配或 `re:` 正则；主包 `dest` 忽略并提示。`skipExistsCheck` 默认 `false`，控制最终下载地址探测。

### json 源

```jsonc
"source": {
  "kind": "json",
  "apiUrl": "https://data.services.jetbrains.com/products/releases?code=IIU&latest=true&type=release",
  "itemsKey": "IIU",                   // 可选：条目（或条目数组）所在字段；缺省 = 整个响应就是一个条目
  "versionKey": "version",              // 可选：版本字段名
  "versionKind": "semver",              // 可选：未写 versionKey 时从下载地址识别
  "versionBetween": [ "v", "-" ],
  "files": [
    {
      "urlKey": "downloads.windowsZip.link",       // 必填：下载地址的字段名
      "file": "*.win.zip",                          // 可选：在多个候选条目里按文件名挑
      "hashKey": "downloads.windowsZip.checksum",   // 可选：sha256 摘要字段
      "hashFileKey": "downloads.windowsZip.checksumLink",  // 可选：校验文件地址字段
      "match": { "distribution": "opencode" }       // 可选：在候选条目里按字段值挑
    }
  ]
}
```

- `apiUrl` 必填且固定，**不支持占位符**（含 `{version}` / `{versionMajor}` / `{tag}` 会报错）
- `itemsKey` / `versionKey` / `urlKey` / `hashKey` / `hashFileKey` / `match` 的键都支持点分嵌套与数组下标（如 `products.0.url`），含特殊字符的键用引号（`files.'x.zip'.url`）
- 主包必须写 `urlKey`；只写 `file` 无法定位安装包（会报错）。`urlKey` 与 `file` 可以搭配：`file` 用于在候选条目里按文件名挑选。
- 第 2 项起是配套文件，必须写完整地址 `url`，不能用 `urlKey`；`hashKey` / `hashFileKey` 只在主包读取。
- 版本优先取 `versionKey`；未写它时，`versionBetween` 优先于 `versionKind` 从下载地址识别，失败记提示并回退条目 `version`。
- `skipExistsCheck` 默认 `false`，控制接口给出的主包地址探测。

### magnet 源

```jsonc
"source": {
  "kind": "magnet",
  "versionKind": "semver",             // 可选：从文件名 dn 识别
  "versionBetween": [ "v", " " ],      // 可选
  "files": [ "magnet:?xt=urn:btih:..." ]
}
```

- `source.files` 至少一项；地址必须是完整磁力链接（`magnet:` 开头）；不接受 `{version}` / `{versionMajor}` / `{tag}` 占位符
- 只有声明 `versionKind` 或 `versionBetween` 时才从文件名（`dn` 参数）识别；两者同写时只用 `versionBetween`。识别不出或都没声明时回退条目 `version`
- 文件大小从 `xl` 参数取；`files[].name` 可覆盖文件名，未写时用 `dn`
- 交给 `FluxDown-CLI`（下载引擎）以 BitTorrent 任务取包

## 版本号处理

### 占位符

| 占位符 | 展开为 | 可用位置 |
|---|---|---|
| `{version}` | 本次解析出的版本 | `files[].url` / `file` / `name` / `hash` / `hashFile` / `versionListUrl`、`postInstallCopy.from` / `to`、`postInstall` / `uninstall.commands` 的 `exe` / `args`、`installArgs` / `uninstallArgs` / `installerExe`、`mainExe`、`keep`、`env` 的值、`addToPath`、`detect.name` / `versionKind` / `pathGlob` / `jsonKey` / `versionArgs` / `exe` |
| `{versionMajor}` | 版本号按 `.` 切分的第一段（`2.57.1` → `2`） | 同上 |
| `{tag}` | GitHub release tag（按 URL 路径段转义） | github 源的 `files[].url` / `file` |
| `{urlQuery:参数名}` | 本文件下载地址查询串里该参数的值 | `files[].hashFile` |
| `{installDir}` / `{installRoot}` | 实际路径 | `installArgs`、`env`、`addToPath`、`postInstall`、`uninstall.commands`、`detect.pathGlob` / `detect.exe`；`postInstallCopy` 只按安装目录内的相对路径使用 |
| `%VAR%` | `env` / `addToPath` 中原样写入；执行命令前展开 | `env` / `addToPath` / `postInstall` / `uninstall.commands` |

`{installDir}` 与 `%VAR%` 的区别很重要：前者是 winst 自己的路径，后者是对其它环境变量的引用（如 `%JAVA_HOME%\bin`），在 `env` / `addToPath` 中保留下来才能在用户切换版本时自动跟随。

`installArgs` 未写在双引号内的 `{installDir}` / `{installRoot}` 会自动按单个参数加引号。`postInstall` / `uninstall.commands` 的展开顺序是先展开 `%VAR%`，再替换 `{installDir}` / `{installRoot}`；版本占位符在来源解析阶段已经展开。

### 版本标识器

`versionKind` 内置三种：

| kind | 匹配 | 例子 |
|---|---|---|
| `semver` | `1.2` / `1.2.3` / `1.2.3.4`，可带 `v` 前缀 | `v24.9.0` → `24.9.0` |
| `date` | `2026-09-07` / `2026.09.07` / `20260907` | |
| `digits` | 2 位以上纯数字 | `20326` |

`versionBetween` 写成 `[ "前缀", "后缀" ]`；后缀可省略为 `[ "前缀" ]`，表示取到文本末尾。前缀不能为空，数组不能多于两项；标记按字面量、区分大小写查找。它适合版本号夹在固定文本里的场合（`["Temurin-", " "]`）。

direct / page 的版本文本识别先按 `versionBetween` 截取，再按 `versionKind` 提取；两者都没写时不从任意文本猜版本，由各来源回退条目 `version` 或明确报错。github 的 `file` / `releaseTitle` / `releaseBody` 及 detect 使用同一截取与识别组合。json / magnet 同写两者时只用 `versionBetween`。packageVersion 两个识别字段都不写时才取第一个像版本号的字符串；detect 的无识别规则兜底见「版本检测」。

### 版本改写（`versionRewrite`）

把上游的版本写法归一成本地比较 / 展示用的写法。三种等价写法，**一条规则只能用一种**，多条写成数组按顺序应用：

```jsonc
{ "from": "jdk8u{u}-b{b}", "to": "1.8.0_{u}-b{b}" }   // 模板（推荐）
{ "stripPrefix": "jdk-" }                              // 去前缀（字面量，不涉正则）
{ "stripSuffix": "-beta" }                             // 去后缀
{ "pattern": "^v", "replace": "" }                     // 正则（高级）
```

- 模板写法的 `{占位符}` 在 `from` 与 `to` 里同名对应；`to` 写空串 `""` 表示整段去掉
- 正则写法的 `replace` 沿用 .NET 正则替换语法（`$1` / `${name}` 引用捕获组）
- 单条规则匹配不上时保持原值（幂等）
- 声明了但没有任何有效规则、或一条规则里混用多种写法，清单报错

三处作用域，用途互不重叠：

| 位置 | 作用对象 |
|---|---|
| `source.versionRewrite` | 源侧解析出的版本（tag / 文件名 / 页面 / 接口 / 包内信息） |
| `detect.versionRewrite` | 本机检测出的版本（`registry` / `fileVersion` / `cliVersion` 等全部检测方式） |
| `files[].versionRewrite` | 只作用于该文件的地址模板展开，不影响主包版本 |

两侧都要归一就各写一份；`{version}` / `{tag}` 仍用改写前的原始值展开，原始值记在解析锁的 `sourceVersion`。

### 版本比较规则

1. 去 `v` 前缀与首尾空白。
2. 两侧都是严格 SemVer 2.0.0 时按 SemVer 比较：逐段比较预发布标识，构建元数据不参与优先级。
3. 其它写法按数字串 / 字母串切分，非字母数字分隔符忽略；数字段都按数值比，其余段不区分大小写比较；缺段补 `0`（`1.0` = `1.0.0`，`1.8.0_504` = `1.8.0.504`）。
4. `-` 后的预发布后缀整体低于同版本正式版；两侧都有后缀时按同一分段规则比较。

## 文件级属性

`source.files[]` 的每一项（主包与配套文件都一样）可带：

| 字段 | 默认 | 说明 |
|---|---|---|
| `url` | — | 下载地址或地址模板 |
| `file` | — | 文件名匹配规则（通配或 `re:` 正则） |
| `urlKey` | — | 仅 `json` 源：接口里存放下载地址的字段名 |
| `dest` | 空 = 安装目录根 | 配套文件落位路径（相对安装目录，不允许绝对路径与 `..`）；声明 `extract` 时是解压目标；主包上的 `dest` 忽略并提示 |
| `extract` | `false` | 该文件是压缩包，安装时解压到 `dest`（仅配套文件） |
| `stripTopDir` | `false` | `extract` 时该压缩包自己的剥壳设置 |
| `name` | 空 = 从地址或来源推导 | 下载产物文件名（地址里带不出文件名时用；magnet 源也可覆盖 `dn`）；github 的 `file` 使用实际资产名 |
| `hash` | 空 = 不校验 | 固定摘要。算法由长度推断：32 → MD5，40 → SHA1，64 → SHA256，128 → SHA512；其它长度按 SHA256 计算。`hash` 优先于 `hashFile` |
| `hashFile` | 空 | 外部校验文件的地址；与 `hashFrom` 搭配；只有 `hashFrom` 而没有 `hashFile` 不会触发校验 |
| `hashFrom` | 有 `hashFile` 时 = `sha256sums`，否则不生效 | 校验值的提取方式，见下方枚举 |
| `hashKey` | 空 | 仅 `json` 主包：接口里摘要的字段名；字段缺失或内容不是 32～128 位十六进制即报错，实际算法仍由摘要长度决定 |
| `hashFileKey` | 空 | 仅 `json` 主包：接口里校验文件地址的字段名；字段缺失即报错，可配 `hashFrom` |
| `match` | 空 | 仅 `json` 主包：对象，键为字段路径、值为期望文本；在多个候选条目里筛选，所有条件都满足才命中，比较不区分大小写 |
| `refresh` | `auto` | 新鲜度判定，见下方枚举 |
| `maxAgeHours` | `168` | `ttl` / `auto` 的 TTL 兜底；非正数回退 168 |
| `compare` | `auto` | 无摘要时的比对判据，见下方枚举；空值及无法识别的值按 `auto` |
| `versionListUrl` | 空 | 该配套文件独立去版本列表页找最新版（不跟随主包版本节奏）；只支持 `url` 模板定位的文件 |
| `versionKind` | 空 = 用 `source.versionKind` | 配合 `versionListUrl` 收集候选；此时本文件或 source 层必须至少写一处 |
| `versionFilter` | 空 | `versionListUrl` 的候选过滤，通配或 `re:` 正则 |
| `versionRewrite` | 空 | 只作用于该文件的地址模板展开与文件版本记录，不影响主包和其它文件 |

`url`、`urlKey` 分别与 `file` 互斥；`url` 与 `urlKey` 也互斥，同时写会报错。**例外是 json 主包的 `urlKey` + `file`，这是允许且常用的组合**：前者定位接口字段，后者筛选候选条目。`urlKey` 只能用于 `json` 源。page 主包不能写 `url`，只能写 `file`；各来源具体必填组合见前文。

`versionListUrl` 的列表页地址可用主包版本展开 `{version}` / `{versionMajor}`；候选经 `versionFilter` 后按版本从高到低探测最终文件地址，上限 8 个，第一个非 404 的采用，`source.skipExistsCheck` 可关闭探测。它只适用于 listing / page / json 第 2 项起的 `url` 配套文件；direct 不读取它，主包和 json 的 `urlKey` 地址不能使用。github 的 `url` 项不读取它，`file` 项虽会进入独立列表解析，但随后仍因定位不是 `url` 而报错，所以 github 条目不要使用 `versionListUrl`。

`hashFrom` 的全部取值：

| 取值 | 含义 |
|---|---|
| `sha256sums` | 逐行 `<摘要>  <文件名>`，按文件名匹配（默认） |
| `sha512sums` | 同上，SHA-512 |
| `sha1sums` | 同上，SHA-1 |
| `md5sums` | 同上，MD5 |
| `sha256` | 文件里只有一串摘要（如 Maven 的 `.sha256`），不按文件名 |
| `sha512` | 同上，SHA-512 |
| `sha1` | 同上，SHA-1 |
| `md5` | 同上，MD5 |
| `re:<正则>` | 自定义正则提取，命名组 `h` 或第 1 捕获组 |
| `page` | 仅 `page` 源、仅主包：从下载页按文件名就近提取摘要（不能与 `hash` 同写） |

`refresh` 的全部取值（大小写、`-` 与 `_` 不敏感；无法识别时按 `auto` 并在 `--verbose` 提示）：

| 取值 | 行为 |
|---|---|
| `auto` | 有摘要按摘要比对；无摘要时联网确认一次（`compare` 判据）；都拿不到时退到 TTL 兜底 |
| `always` | 每次都重新下载 |
| `ifMissing` | 缓存里有就不再确认，永远命中 |
| `check` | 必须靠校验器 / 摘要确认；拿不到校验信息就重取，不做 TTL 兜底 |
| `ttl` | 距上次确认未超 `maxAgeHours` 则命中，否则联网确认一次 |

`compare` 的全部取值：

| 取值 | 行为 |
|---|---|
| `auto`（默认） | 比 `ETag` + `Last-Modified` + 文件大小（记录里有哪项比哪项） |
| `size` | 只比文件大小——主机 `ETag` / `Last-Modified` 会漂移时用（如 `dl.google.com`） |

`--offline` 下声明过 `hash` / `hashFile` 的缓存文件必须能重新验证；验证不了就报「离线缓存无法验证」而不会静默使用。

## 命令条目

`postInstall` 与 `uninstall.commands` 共用同一结构：

| 字段 | 默认 | 说明 |
|---|---|---|
| `exe` | 必填 | 可执行文件；相对路径按安装目录解析，支持 `{installDir}` / `{installRoot}` / `{version}` 与 `%VAR%`；空 `exe` 的规则跳过，路径含双引号或控制字符、文件不存在时执行失败 |
| `args` | 空 | 命令行片段（允许带引号）；不允许换行等控制字符 |
| `timeoutSec` | `600` | 超时秒数；超时按进程树结束并判为该步失败；≤ 0 回退 600 |
| `requireAdmin` | `false` | 为真时先检查当前进程是否管理员，不是则明确报错、不执行 |

`postInstall` 的退出码不是 `0` / `1641` / `3010` 即安装失败（后两者表示已发起重启 / 需重启才能完成）。`uninstall.commands` 在**删目录 / 跑官方卸载器之前**执行（如 `regsvr32 /u` 注销滤镜时文件还在原地），失败即中止卸载，`--force` 跳过。

## 版本检测（`detect`）

`detect.method` 决定怎么读本机已装版本。**全部取值**：

| `method` | 版本来源 | 该方式用到的字段 | 说明 |
|---|---|---|---|
| `none`（默认，`installer` 除外） | 不检测 | — | 每次都按未安装处理 |
| `registry` | 系统卸载记录（HKLM / HKCU 的 `Uninstall` 键） | `name` | `installer` 未声明 `detect` 时的默认值，`name` 自动生成为 `*<name>*` |
| `fileVersion` | 文件的版本资源 | `pathGlob` | 取 `FileVersion` / `ProductVersion`；字符串与数值体不一致时以数值体为准（除非字符串是它的数字前缀） |
| `markerFile` | 标记文件的内容 | `pathGlob` | 文件内容常就是版本号本身 |
| `jsonFile` | JSON 文件里的字段 | `pathGlob`、`jsonKey` | 从 `pathGlob` 命中的文件里取 `jsonKey` 字段 |
| `appx` | 系统应用包记录 | `name` | 按包名规则匹配；检测使用单条字符串规则，卸载规则才可为数组 |
| `cliVersion` | 运行程序取版本 | `exe`、`versionArgs` | `exe` 未写时用 `mainExe`；程序必须把版本写到 stdout / stderr（直接写控制台的拿不到） |

`detect` 的公共字段：

| 字段 | 默认 | 说明 | 适用 method |
|---|---|---|---|
| `method` | 见条目字段表 | `none` / `registry` / `fileVersion` / `markerFile` / `jsonFile` / `appx` / `cliVersion` | 全部 |
| `name` | `registry` 未写时按 `*<name>*` 推导；`appx` 无默认 | 匹配规则：`registry` 比 `DisplayName`，`appx` 比包名；通配或 `re:` 正则；`appx` 检测只接受单条字符串规则 | `registry` / `appx` |
| `pathGlob` | 空 | 文件定位通配（支持 `{installDir}` / `{installRoot}`）；命中多个时逐个读取、取版本最高的那个作为本机版本（其余记为旧版本） | `fileVersion` / `markerFile` / `jsonFile` |
| `jsonKey` | 空 | JSON 里的版本字段名（支持点分嵌套） | `jsonFile` |
| `exe` | `mainExe` | 要运行的程序（相对安装目录或绝对路径） | `cliVersion` |
| `versionArgs` | 空或未写时 = `-v` | 取版本时传给程序的参数（如 `--version`） | `cliVersion` |
| `versionKind` | 空 | 从原始文本里识别版本的识别器 | 全部 |
| `versionBetween` | `[]` | 用两个标记截取版本 | 全部 |
| `versionRewrite` | 空 | 归一化检测结果 | 全部 |

约束：

- `detect.exe` 只对 `cliVersion` 有效；`method` 是别的时写了会报错（要求改用 `pathGlob`）
- `detect.name` 与 `detect.versionKind` 会在清单解析期编译校验，写错即条目解析失败
- 未声明 `versionKind` / `versionBetween` 时，原始文本整体像单行版本号就原样采用；否则按 `semver` → `date` → `digits` 找第一个像版本号的内容。`markerFile` 即使声明了识别规则但未命中，也执行这个兜底；其它方式不兜底。
- `cliVersion` 在一个独立隐藏进程里运行，`stdin` 立即关闭；先读 `stdout`，未识别再读 `stderr`，直接写控制台而不走重定向的输出拿不到。运行超时固定 10 秒，会连同子进程一起结束。
- 同一软件在本机装过多份时，`registry` / `fileVersion` / `markerFile` / `jsonFile` 读出全部命中版本，以最高版本作为本机版本，其余记为旧版本；`registry` 同时命中外层引导包与内层 MSI 时只采用外层引导包的 `DisplayVersion`；`appx` 只取版本最高的包。详见 `docs\install-flows.md` 的「版本检测」。

## 卸载定义（`uninstall`）

| 字段 | 默认 | 说明 |
|---|---|---|
| `commands` | `[]` | 卸载命令（结构同「命令条目」）；在删目录 / 跑官方卸载器之前执行，失败即中止，`--force` 跳过 |
| `name` | 未写时 = `detect.name` | `appx` 卸载时的包名规则；可为字符串或数组，命中任意一条即移除；仅卸载应用包时读取 |
| `uninstallArgs` | 不支持 | 卸载参数必须写条目级 `uninstallArgs`；写在这里不会生效，应用包卸载也不使用它 |

卸载方式由 winst 根据 `type` 与主包扩展名自动判定，清单不能直接指定。内部方法名（仅出现在详情页与排错信息里）：

| 内部方法 | 触发条件 |
|---|---|
| `portable-dir` | `portable` / `file` 条目：删安装目录 + 回收系统项 |
| `registry` | `installer` 条目：实时回读注册表并运行官方卸载器 |
| `appx` | 主包是应用包，或 `detect.method` 为 `appx`：从系统应用包记录移除 |
| `clean-cache` | `download` 条目：删除已下载的软件包 |
| `record-only` | 不是 winst 安装、且软件源里没有卸载定义：只移除安装记录 |

## 包内版本派生（`source.packageVersion`）

安装包的文件版本信息不可信时（如 Chrome 离线安装器的 `FileVersion` 与包内真实版本不一致），声明它让 winst 用 7-Zip（`7-Zip-CLI` 引擎）读包内结构派生版本。**必须配合 `source.versionFrom: "package"`**。

```jsonc
"source": {
  "kind": "direct",
  "versionFrom": "package",
  "packageVersion": {
    "file": "*.exe",                       // 可选：外层包文件通配，缺省 = 主包
    "inner": "updater.7z",                 // 可选：外层包里要先取出的内层压缩包（取第一个命中）
    "path": "*_chrome_installer.exe",      // 必填：最内层压缩包里要匹配的条目路径
    "versionKind": "semver",               // 可选：从命中条目的文件名识别版本
    "versionBetween": [ "v", " " ]         // 可选
  },
  "files": [ { "url": "https://example.com/ChromeStandaloneSetup64.exe" } ]
}
```

| 字段 | 必填 | 说明 |
|---|---|---|
| `path` | 是 | 最内层压缩包里的条目路径通配（取第一个命中） |
| `file` | 否 | 外层包文件通配，缺省 = 主包 |
| `inner` | 否 | 外层包里需要先取出的内层压缩包（取第一个命中） |
| `versionKind` | 否 | 从命中条目文件名识别版本的识别器 |
| `versionBetween` | 否 | 用两个标记截取版本 |

- 只接受上表五个键；写了别的会报错并列出可用键
- `versionKind` 必须是 `semver` / `date` / `digits` 之一
- 两个识别字段都不写时，按「第一个像版本号的内容」兜底

## 源刷新与解析锁

- 刷新软件源时会对清单内**全部条目**执行一次来源解析，结果写入 sidecar（`<pkgDir>\manifests\remote\<源>.meta.json` 的 `apps` 字段），形成「解析锁」
- `install` / `download` 优先复用锁里的结果，锁未命中才在运行时重新解析
- 每条记录带 `resolvedAt`，用于判断展示用的版本信息是否过期（`manifestTTLHours`）
- 单条解析失败不影响其它条目：记为 `ok: false` + `error`，刷新整体仍算成功
- 「下载地址 HEAD 可用性校验」在刷新阶段做：`404` / `410` 判为条目解析失败（提示清单地址失效），网络错误 / `405` 不判失败；`skipExistsCheck: true` 可关掉
- 例外：响应带 `Cf-Mitigated: challenge`（Cloudflare 人机校验页）时不判失败，按「未能确认」记一条备注。这类 CDN 对 .NET / PowerShell 客户端一律回 404（JetBrains 的中国 CDN 就是如此），文件其实存在、下载引擎也下得动，按 404 报错只会冤枉清单；代价是这类站点上「真的写错了地址」同样只能等到安装时才暴露
- 同一进程内对「方法 + URL」的响应做 TTL 10 分钟缓存（GitHub 网页通道、`listing` / `page` 页面、`json` 接口、校验文件、HEAD 探测），进程退出即失效

## 依赖与分组

- `dependencies` 是「安装这个之前需要装什么」，winst 只处理未装 / 可更新的部分，与本体一起确认
- 依赖**不会**自动写进安装清单：清单只记录用户显式选择，安装时再补齐依赖
- 卸载时列出「哪些已安装软件依赖它」，仅提示、不拦截
- `bundle pack` 会收集依赖闭包
- `group` 只影响展示顺序与分组标题，不参与版本比较和安装流程

## winst 内置使用的条目 id

只有三个 id 被 winst 自己识别（写死在代码里），它们必须在软件源里存在、且保持这个 id：

| id | 用途 | 何时自动安装 |
|---|---|---|
| `winst` | winst 自身（`type: portable`，主程序 `winst.cmd`） | 安装任意其它软件前（`Confirm-WinstSelf`）；已装则检查并应用更新 |
| `7-Zip-CLI` | 解压引擎，只落地 `7z.exe` + `7z.dll`（靠 `extractFiles`） | 每次解压前（`Confirm-WinstExtractEngine`） |
| `FluxDown-CLI` | 下载引擎（`fluxdown.exe`） | 每次下载前（`Confirm-WinstDownloadEngine`） |

这三个 id 之外的条目（包括同名的图形版软件）winst 不认识、也不会自动安装——它们和普通软件完全一样，由用户自己选择安装。`--offline` 下若缓存里没有引擎包，会明确报错并提示用 `winst install winst --from <zip>` 做离线自安装。

引擎与图形版互不影响：安装图形版 7-Zip / FluxDown 不会替代或影响 `7-Zip-CLI` / `FluxDown-CLI`，反之亦然——它们的安装目录与主程序都不同。

## 常见写错与报错

| 现象 | 原因 |
|---|---|
| `不认识的版本来源「x」（source.versionFrom）` | 该 kind 不支持这个取值，见「六种下载来源」表 |
| `versionFrom: file 但没有写 versionKind / versionBetween` | github 的 `file` 必须给出识别方式 |
| `写了 versionKind 但没声明 versionFrom: file` | github 默认用 tag 当版本，要取文件名里的版本必须显式声明 |
| `source.link 与 source.click 只能写一个` | 两者互斥 |
| `source.link 至少要写一个条件` | `source.link` 是空规则；`source.thenLink.link` 为空时也有对应的明确报错 |
| `urlKey 只能用在 JSON 接口源里` | `urlKey` 是 json 专属 |
| `同一个文件不能同时填写 url 和 file` | `url` / `urlKey` / `file` 的互斥组合写错；json 主包允许 `urlKey` + `file` |
| `source.packageVersion 只配合 versionFrom: "package"` | 派生规格必须与 package 版本来源搭配 |
| `detect.exe 只对 cliVersion 有效` | 别的检测方式要用 `pathGlob` |
| `软件源条目 id 不合法` | id 不是单层目录名（含 `/` `\` `..` 或超长） |
| `installArgs 含有控制字符或未闭合的双引号` | 参数模板必须引号配对 |
| `软件源里的解压路径…不能包含上级目录（..）` | `extractFiles` / `stripTopDir` / `installerExe` / `postInstallCopy` 都不允许越界 |
