# 软件源与清单

本文是第三方编写软件源的完整参考：字段、枚举取值与约束对应 winst 的实际解析逻辑，写错时 `manifest` 刷新 / 安装会给出明确报错。

## 按安装动作选择最小条目

先选 `type`，再独立选择 `source.kind`：软件发布在 GitHub 不代表它必须解压，下载文件扩展名也不决定条目类型。

| 需要做什么 | `type` | 再补哪些字段 |
|---|---|---|
| 解压到 winst 管理的目录 | `portable` | 主程序 `mainExe`，需要保留的用户文件写 `keep` |
| 运行厂商安装器或安装应用包 | `installer` | 厂商需要时写 `installArgs`；默认从注册表检测，应用包显式配置 `detect` |
| 复制一个程序或数据文件 | `file` | 主程序自动取下载文件；需要时配置快捷方式或 PATH |
| 只保存软件包 | `download` | 不填写安装、版本检测与卸载字段 |

以下均是完整条目对象，可放入 catalog 的 `apps` 数组，也可单独保存为本地清单。`example.com` 地址用于展示结构，实际使用时替换为软件发布者提供的地址。

绿色压缩包：显式选择 `fileVersion` 后，检测路径默认取 `mainExe`；省略 `detect` 则不自动开启检测。

```json
{
  "id": "DemoPortable",
  "type": "portable",
  "source": {
    "kind": "direct",
    "version": {"value": "1.2.3"},
    "files": [{"url": "https://example.com/demo-1.2.3.zip"}]
  },
  "mainExe": "demo.exe",
  "detect": {"method": "fileVersion"}
}
```

厂商安装器：静默参数由具体安装器决定，不在通用模板中猜测。

```json
{
  "id": "DemoInstaller",
  "name": "Demo Installer",
  "type": "installer",
  "source": {
    "kind": "direct",
    "version": {"value": "1.2.3"},
    "files": [{"url": "https://example.com/demo-setup-1.2.3.exe"}]
  }
}
```

单文件程序：不填写 `mainExe`；需要加入 PATH 时使用明确的路径数组。

```json
{
  "id": "DemoFile",
  "type": "file",
  "source": {
    "kind": "direct",
    "version": {"value": "1.2.3"},
    "files": [{"url": "https://example.com/demo.exe"}]
  },
  "addToPath": ["{installDir}"],
  "detect": {"method": "fileVersion"}
}
```

仅下载的软件包：

```json
{
  "id": "DemoDownload",
  "type": "download",
  "source": {
    "kind": "direct",
    "version": {"value": "1.2.3"},
    "files": [{"url": "https://example.com/demo-1.2.3.iso"}]
  }
}
```

| 发布者提供什么 | 优先选择的 `source.kind` | 阅读位置 |
|---|---|---|
| 官方 JSON / XML 版本元数据，含平台与架构字段 | `json` / `xml` | 先筛选目标平台与正式版本，再定位文件 |
| GitHub Releases 资产 | `github` | 通常只需 `repo` 与文件名匹配规则，版本默认取 tag |
| 目录索引 | `listing` | 版本候选从 `indexUrl` 获取，文件使用地址模板 |
| 固定下载地址，版本来自单独接口、响应头或已知常量 | `direct` | 版本规则集中写在 `source.version` |
| 下载网页或需点击的按钮 | `page` | 用 `link` / `click` 定位下载地址 |
| 磁力链接 | `magnet` | 用文件名中的版本识别规则 |

先确认官方元数据能区分目标平台、架构与正式版本；无法使用时再从下载页面提取。复杂来源的规则见下文，不需要在每条清单中重复默认值或空数组。

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

## 调试本地清单

本地清单（`local`）改完不用加源、不用重启，但**每条软件的版本信息有 24 小时有效期**（`manifestTTLHours`）：
有效期内的 id 直接沿用解析锁里的旧值，改完清单立刻查看可能还是旧结果。按下面的顺序验证：

| 目的 | 命令 |
|---|---|
| 只重新解析一个 id（忽略有效期） | `winst info <id> --force` |
| 整源重解析，逐条打印每个条目的版本与错误 | `winst manifest update local` |
| 看安装计划（下载地址、校验方式、解压、系统项、版本检测） | `winst install <id> --dry-run` |

- `info <id> --force` 只解析这一个 id，但仍按 `-Force` 的既有语义重新读取全部软件源的清单本体；本地清单正文只从文件读取；条目解析仍会按 source.kind 抓取网页 / API、探测下载地址，可能联网。
- 安装预览不会自动刷新软件源：先跑上面任一条取得解析结果，否则冷缓存下会提示「软件源里没有找到」。显式软件源预览的联网和写入边界见 [CLI 预览边界](cli.md#预览边界)。
- 解析结果写在 `<pkgDir>\manifests\local.meta.json`：每条都带 `ok`、`error` 与解析出的版本与文件，脚本化核对可以直接读它。
- `--offline` 会跳过所有刷新（`manifest update` 直接拒绝执行），调试本地清单时不要加。

## 清单文件格式

标准格式是 catalog 包裹结构：

```json
{
  "_manifestVersion": "2026.10.20",
  "apps": [
    {
      "id": "DemoDownload",
      "type": "download",
      "source": {
        "kind": "direct",
        "version": {"value": "1.2.3"},
        "files": [{"url": "https://example.com/demo-1.2.3.zip"}]
      }
    }
  ]
}
```

清单也兼容顶层数组 `[ {...} ]`、顶层单条目对象（含 `id`）。本地与远程正文均校验根结构与条目对象，`apps` 必须是数组，数组内每项必须含 `id`；空数组及 `{"apps":[]}` 表示空清单。错误对象、标量及其它结构明确报错，保留既有正文缓存与解析锁。

- **纯 JSON**：清单文件与本文 JSON 示例均不写注释
- **编码**：UTF-8（带不带 BOM 均可）；其它编码会导致解析失败并明确报错
- winst 自己写出的文件（清单缓存、`bundle pack` 复制的清单、`.list`）一律 UTF-8 无 BOM
- `_manifestVersion` 只用于人看与排错，winst 不按它做兼容分支；改内置清单时要一起更新

## 写法与校验约定

推荐把来源版本规则集中写为 `source.version`，每个下载文件的摘要规则集中写为 `source.files[].checksum`，卸载参数写为 `uninstall.args`。这些对象是作者配置，解析锁、安装台账中的内部字段不能直接复制到清单。

- 条目及 `source`、`source.version`、`files[]`、`checksum`、`follow`、页面条件、`detect`、`shortcuts`、`uninstall`、复制规则、命令对象中的未知字段会报「不支持字段」，不会静默忽略拼写错误。`env` 的环境变量名与 `match` 的接口字段名由作者指定。
- 声明为字符串的字段不能用数字、对象或 JSON `null` 代替。`version.key` 在 XML 中额外接受非空字符串数组；`version.between` 使用至多两个字符串组成的数组，空数组仅在允许该字段的来源和取版方式中按未配置处理；不适用位置仍报错。
- 布尔字段推荐使用 JSON `true` / `false`；兼容 `"true"` / `"false"` / `"1"` / `"0"` / `"yes"` / `"no"` / `"on"` / `"off"` 及数字 `1` / `0`，不区分大小写；无法识别的值报错。`stripTopDir` 和 `addToPath` 另有下文说明的路径写法。
- 已声明的 `postInstallCopy` 必须有非空 `from` 与 `to`；`postInstall` / `uninstall.commands` 的每项必须有非空 `exe`。省略整个功能或写空数组表示不用它，填写不完整的规则会报出字段路径与下标。
- `source.version` 与任一分散的来源版本字段或根级 `version` 不能混写；同一文件的 `checksum` 与旧 `hash*` 字段不能混写；`uninstall.args` 与根级 `uninstallArgs` 不能混写。字段对应关系见「兼容字段对照」。

推荐的嵌套写法需要使用支持本规范的 winst。发布第三方软件源前应先部署对应程序版本；旧客户端不保证能读取这些对象。

## 通用匹配规则

清单提供的正则匹配、版本 / 摘要提取和 `versionRewrite` 正则替换，每次执行限时 1 秒；超时报出规则及执行用途，本次解析或检测失败，不按普通未匹配继续处理。

`source.files[].file`、`source.files[0].checksum.fileMatch`、`source.version.filter`、`source.follow.versionFilter`、`source.files[].versionFilter`、页面链接条件中的 `href`、`detect.name` 和 `uninstall.name` 使用同一套匹配规则。它们接受以下全部写法：

| 写法 | 匹配方式 |
|---|---|
| 普通文本或通配 | 默认写法，整串匹配且区分大小写；`*` 匹配任意多个字符，`?` 匹配单个字符，反斜杠转义下一个字符，其余字符按字面量处理 |
| `re:<正则>` | 直接使用自定义正则，默认区分大小写；需要完整匹配时自行写出首尾边界，需要忽略大小写时使用正则选项 `(?i)`；正则无法编译时规则报错 |
| `product:<产品名列表>` | 预置的完整产品名称匹配器；接受列出的任一产品名，以及产品名后可选的空白和数字点分版本后缀；产品名按字面量处理且区分大小写，不把 `*`、`?` 或正则元字符当成特殊语法 |
| `preset:stable` | 预置的正式版本格式匹配器；数字主体必须是 2～4 个由点分隔的 ASCII 数字段，可带一个紧贴数字的 `v` / `V` 前缀，首尾允许 .NET 正则 `\s` 匹配的空白（含空格、制表符和换行）；例如 `160.0`、`10.0.1`、`1.2.3.4`、`v2026.11.11` 和带首尾空格的 `V2026.11.11` 均匹配。不接受单段或超过四段的版本、重复前缀、版本内部空白、任何后缀（包括 `b1`、`-rc.1`、`esr`、`+build`） |

`re:`、`product:` 和 `preset:` 前缀不区分大小写，前面可以有空白；未使用这些前缀时按通配处理。`preset:` 后的名称去掉首尾空白后只接受 `stable`，名称不区分大小写；其它名称报「不认识的预置匹配规则」。`preset:stable` 只检查文本格式，不查询发布状态，适用于上述所有使用通用匹配规则的位置。页面条件的 `class` / `id` / `text`、文件系统路径通配、摘要格式 `checksum.format` 与版本识别器分别使用各自的规则，不使用此匹配器。

`product:` 后用 `|` 分隔产品别名，每个别名会去掉首尾空白。示例 `product:微信|WeChat|Weixin` 接受「微信」「WeChat」「Weixin」「微信 4.2.0」，不接受「企业微信」「WeChat Work」「微信测试版」。版本后缀是至少一个空白字符，后接一个或多个以点分隔的数字段，如 `4`、`4.2.0`；版本前后不能额外夹带其它文字。`product:` 后没有名称、连续 `||`、末尾 `|` 或仅含空白的别名，均报「product: 预置规则的产品名不能为空」。`|` 只作分隔，名称自身含此字符时应使用 `re:` 自定义规则。

例如，微信的注册表版本检测可写为：

```json
{
  "detect": {"method": "registry", "name": "product:微信|WeChat|Weixin"}
}
```

## 条目字段

| 字段 | 默认值 | 说明 |
|---|---|---|
| `id` | 必填 | 单层目录名，**区分大小写**；但不允许与现有台账、缓存或目录中的 id 仅大小写不同，冲突时报错且不覆盖已有身份；不能为空、`.` / `..`、首尾空白、尾点、控制字符、Windows 文件名非法字符、保留设备名或超过 100 字符。绿色版安装目录 = `<installRoot>\<id>`，包目录 = `<pkgDir>\<id>` |
| `name` | `= id` | 显示名；`installer` 未声明 `detect.name` 时也用它生成注册表匹配规则 |
| `description` | 空 | 一句话说明，参与 `search` 的关键字匹配 |
| `homepage` | 空 | 作者提供的项目主页元数据，接受字符串；不参与下载定位、版本检测或安装决策 |
| `type` | 必填 | 见下方「条目类型」 |
| `group` | 空 | 展示分组，列表里同组聚拢并打分组标题；不参与版本比较与安装流程 |
| `dependencies` | `[]` | 依赖 id 列表；安装 / 更新前先处理「未装 / 可更新」的依赖；卸载时提示但不拦截；`download` 条目不参与 |
| `version` | 不填写 | 固定版本的兼容字段，只能用于 `direct`；推荐 `source.version.value`。不能与 `source.version` 或动态取版规则混写 |
| `source` | 必填 | 下载来源定义，见「下载来源」 |
| `stripTopDir` | `true` | `portable` 的主包解压规则，或 `installer` 声明 `installerExe` 时的外层包解压规则。`true` 剥掉唯一顶层目录；`false` 原样解压；字符串 = 只取包内该路径（目录取内容、文件取自身；该文件本身是压缩包则再解压一层）；路径不存在即报错 |
| `extractFiles` | `[]` | 仅 `portable`：只取包内这几个路径；声明后不再看 `stripTopDir`；任一不存在即报错 |
| `portableMode` | `clean` | 仅 `portable`：确认解压引擎可用后，在 Temp 下的随机暂存目录完成解压、布局选择、非空及路径安全检查；`clean` 在原安装位置按 `keep` 清理，清理成功后复制新文件，不改旧目录名、不备份、不回滚，不计算暂存或落位文件摘要。`overwrite` 不清理旧目录，直接复制并合并覆盖，也不回滚。引擎不可用或暂存检查失败时保留旧目录；清理失败不开始复制，清理或复制失败可能留下不完整目录并明确报错。省略或空字符串按 `clean`；其它非空值必须是 `clean` / `overwrite`，写错报「不支持的 portableMode」 |
| `keep` | `[]` | 仅 `portable` 的 `clean` 模式：相对安装目录的保留路径通配；支持 `*`（单层）/ `**`（跨层）/ `?`，不写分隔符时按文件名匹配（任意层都保留）；新包中的同名文件仍会覆盖保留内容；`overwrite` 模式不使用 |
| `mainExe` | 空 | 仅 `portable`：主程序相对路径（快捷方式目标、进程检测、`cliVersion` 入口）；`file` 的主程序自动取主包落位文件 |
| `addToPath` | `[]` | `portable` / `file` 加入 PATH 的路径；布尔 `true` 或字符串 `"true"` 表示安装目录本身；字符串 `"false"` / `"0"` / `"no"` / `"off"` 会被忽略 |
| `env` | `{}` | `portable` / `file` 的环境变量；必须为对象，值必须为字符串；`{installDir}` 展开为实际安装目录，`%VAR%` 原样写入；作用域按安装目录自动判定（`%USERPROFILE%` 下 → User，否则 Machine） |
| `shortcuts` | 均为 `false` | `portable` / `file` 的 `desktop` / `startMenu`，目标为主程序；主程序是 `.ps1` 时自动生成同名 `.cmd` 启动器 |
| `postInstallCopy` | `[]` | `portable` / `file`：安装目录内复制 / 改名（`move: true` 为移动），`from` / `to` 均为相对路径，`from` 支持 `*` / `?` 通配；缺少或空白 `from` / `to` 时报含规则下标的字段错误；`from` 无命中或命中多个即报错 |
| `postInstall` | `[]` | `portable` / `file`：安装末尾执行的命令，非零退出视为安装失败；字段见下方「命令条目」 |
| `installArgs` | 空 | 仅 `installer`：静默安装参数；应用包安装不使用它；含未闭合双引号或控制字符时清单报错 |
| `uninstallArgs` | 空 | `uninstall.args` 的根级兼容写法；不能与 `uninstall.args` 同写；应用包卸载不使用它 |
| `installerExe` | 空 | 仅 `installer`：主包是压缩包时，先解压再运行包内这个安装程序（支持 `{version}` 与 `*` / `?`）；无命中或命中多个即报错；声明它时 `stripTopDir` 表示外层包的解压规则 |
| `processes` | `[]` | 进程名列表，见表后的「进程占用检测」；`download` 不安装，无需声明 |
| `uninstall` | 空 | 卸载定义，见「卸载定义」；`download` 不使用 |
| `detect` | `installer` → `registry`，其余 → `none`；省略对象、空对象和缺省 / 空 `method` 使用同一默认；关闭检测需显式 `method: "none"` | 已装版本检测，见「版本检测」；`download` 强制为 `none` |

**不同类型忽略的字段**：

- `installer` 忽略 `stripTopDir`（除非声明了 `installerExe`）、`portableMode`、`keep`、`mainExe`、`addToPath`、`env`、`shortcuts`、`postInstallCopy`、`postInstall` —— 安装位置与系统设置都由安装程序自己管理。写了会记一条提示，不会静默生效。
- `download` 只保留下载来源与公共元数据；忽略全部安装、进程检测、系统设置、版本检测和卸载字段（`processes` / `stripTopDir` / `extractFiles` / `portableMode` / `keep` / `mainExe` / `addToPath` / `env` / `shortcuts` / `postInstallCopy` / `postInstall` / `installArgs` / `uninstall.args` / `installerExe` / `detect` / `uninstall`）。
- `file` 忽略 `stripTopDir`、`extractFiles`、`portableMode`、`keep` 和 `mainExe`。主程序 = 主包落位文件；`postInstallCopy` 中与主包文件名完全一致的 `from` 且 `move: true` 时，主程序取该规则的完整相对路径 `to`（如 `bin/tool.exe`），保留子目录；仅复制不改变主程序。

### 解压配置怎么选

| 目标动作 | 主包配置 | 行为 |
|---|---|---|
| 解压并去掉唯一顶层目录 | 省略 `stripTopDir`，或填写 `true` | 没有唯一顶层目录时保留原布局 |
| 保留包内完整布局 | `stripTopDir: false` | 不去顶层目录 |
| 只取一个目录的内容或一个普通文件 | `stripTopDir` 写包内相对路径字符串 | 路径不存在时报错；目录取内容，文件取自身 |
| 先解出内层压缩包，再解开它 | `stripTopDir` 写内层压缩包相对路径 | 选中项为受支持的压缩包时再解一层 |
| 选择多个文件或目录 | `extractFiles` 写相对路径数组 | 仅 portable；覆盖 `stripTopDir`，目录取内容，文件取自身；不会把选中的压缩文件再自动解开 |

`extractFiles` 非空时不必再写 `stripTopDir`。配套文件使用自己的 `extract: true`、`dest` 与 `stripTopDir`，其剥顶层默认是 `false`，不会继承主包的默认 `true`。路径选择与数据保留是两件事：`portableMode` / `keep` 决定如何处理旧安装目录。

### 进程占用检测

`processes` 写可执行文件名（通常含 `.exe`），匹配时去掉扩展名且不区分大小写；空项不产生匹配。它补充安装目录归属检测，主要用于 `installer` 无法从系统记录解析安装目录的情况；`portable` / `file` 也可声明：

1. 先按可执行文件路径是否位于该软件安装目录判定；路径确认的进程可在用户选择结束后自动结束。
2. 未被路径命中时，再按 `processes` 声明的名字匹配。仅按名字不能确认归属，即使与主程序同名，也不会自动结束。
3. 仅按名字命中但不能确认归属的进程会列出并要求用户手动关闭；`--kill` 和交互式“结束进程”都不会自动结束它们，以避免误杀同名或共享运行时进程。
4. 路径不可见且未命中 `processes` 时，只有进程名与主程序相同才会作为候选，且不属于可自动结束的一组。
5. 安装 / 更新 `installer` 时，交互提示提供「直接安装」：保留运行中的进程并继续执行安装器，由安装器处理占用；只按名字命中、无法确认归属的进程也允许这样继续。卸载以及 `portable` / `file` 的安装 / 更新没有这个选项；`--yes`、`--kill` 和输入重定向不会自动选择它。
6. 未选择「直接安装」时，结束进程或用户回答之后都重新检测，判定只看重新检测的结果：进程已经不在了就直接继续。「不能自动结束」的进程在重新检测仍命中时中止；结束进程失败在 `--kill` 下立即中止，交互模式下重新提示（最多 5 轮）。

软件 id 禁止使用保留包目录名 `manifests`（含任意大小写变体），清单解析、缓存规划与删除入口均拒绝。

## 条目类型

| `type` | 安装动作 | 卸载动作 | 说明 |
|---|---|---|---|
| `portable` | 解压主包到 `<installRoot>\<id>`，按 `portableMode` / `keep` / `stripTopDir` / `extractFiles` 落地 | `portable-dir`（删目录 + 回收系统项） | 绝大多数绿色版软件 |
| `installer` | 运行安装程序；主包是 `.msix` / `.msixbundle` / `.appx` / `.appxbundle` 时改用 `Add-AppxPackage` | `registry`（跑官方卸载器）；应用包为 `appx` | 安装位置由安装程序决定，安装后回读系统记录 |
| `file` | 把主包复制到 `<installRoot>\<id>`（临时文件 + 原子替换） | `portable-dir` | 单文件绿色版（`.exe` / `.ps1` / `.jar` 等，与格式无关） |
| `download` | 只把包存到 `<pkgDir>\<id>`，不安装、不写台账 | 不适用（用 `clean` 删包） | 「仅下载软件包」类条目 |

`exe` 与 `file` 同义；读取时统一归一化为 `file`。

## 来源版本对象（`source.version`）

整个对象可在使用来源默认取版方式时省略，例如 GitHub 默认使用 tag。对象中的字段只允许用于实际读取它们的来源和取版方式；不适用的组合报错。`follow`、`detect`、`files[]` 独立版本以及 `version.package` 内部的字段名保持各自说明中的写法。

| 字段 | 默认 | 适用范围与约束 |
|---|---|---|
| `value` | 无 | 固定版本字符串，仅 `direct`；非空，只能搭配 `rewrite`，不能与动态取版字段同写 |
| `from` | github 为 `tag`；page 为 `url` | `direct` / `github` / `page` 的版本来源，枚举见下一节；listing / json / xml / magnet 禁止声明 |
| `url` | 无 | direct 的 `from: page` 使用的版本页；direct / page 的 `from: header` 或 `json` 使用的独立版本地址。page 下载页始终写 `source.pageUrl` |
| `header` | 无 | direct / page 的 `from: header` 必填，HTTP 响应头名 |
| `key` | 无 | JSON 的版本字段、XML 的版本路径或路径数组、page 的页面版本字段，以及 direct / page 的 `from: json` 版本字段；不能与 `kind` / `between` 同写 |
| `xpath` | 无 | 仅 XML，与 `key` 二选一，读取完整版本的 XPath |
| `kind` | 无 | 版本文本识别器 `semver` / `date` / `digits`；适用的来源与组合见「版本标识器」与各来源章节 |
| `between` | 无 | 从原始文本截取版本的标记数组；适用的来源与组合见「版本标识器」 |
| `filter` | 不过滤 | listing 候选、JSON 父发布或独立 JSON 版本值的过滤；JSON 必须有 `key` |
| `sort` | listing 为 `semver`；JSON 不排序 | listing 接受 `semver` / `text`；JSON 接受 `semver` 且必须有 `key`。不适用于 XML |
| `rewrite` | 不改写 | 归一化来源版本，单条规则或顺序规则数组，见「版本改写」 |
| `package` | 无 | 主包内部版本派生规格，必须搭配 `from: package`，见「包内版本派生」 |

固定版本与动态版本是互斥的配置方式。page / json / magnet 未配置任何版本读取规则时允许未知版本；写了规则却无法取得版本时明确报错。

## 下载来源

`source.kind` 必填，大小写不敏感。`source.files[]` 第一项是主包，后续项是配套文件；`files` 必须是数组，不能为 JSON `null` 或单个对象；每项可写对象，或写字符串作为 `url` 简写。也可省略 `files`，直接写 `source.url` 表示唯一主包；`files` 与 `source.url` 不能同时声明，即使 `files` 为空也报错。page 源不能靠 `source.url` 提供主包地址，因为它只接受页面提取；json 主包必须写 `urlKey`，xml 主包必须写 `urlKey` 或 `urlXPath`，两者都不能用字符串简写或 `source.url` 替代。`skipExistsCheck` 默认 `false`，对 direct / github / listing / page / json / xml 有效；magnet 不做 HTTP 地址探测，也不接受 `skipExistsCheck`。

| kind | 用途 | `version.from` 可用值 |
|---|---|---|
| `direct` | 固定地址或带 `{version}` 的地址模板 | `page`（官网页面实时取）、`package`（下载后读文件信息）、`header`、`json`；固定版本填写 `version.value`，不得与动态取版规则混用 |
| `github` | GitHub Releases（走网页通道，不用 API） | `tag`（默认，发布 tag）、`file`（下载文件名）、`package`、`releaseTitle`（发布标题）、`releaseBody`（发布正文） |
| `listing` | 版本 / 目录列表页 | 禁止声明 `version.from`；版本由列表页候选 + `version.kind` 决定 |
| `page` | 下载详情页，按元素定位下载按钮 | `url`（默认，从下载地址识别）、`page`（从页面内容识别）、`package`、`header`、`json` |
| `json` | 下载信息只在接口里的站点 | 禁止声明 `version.from`；用 `version.key`，或 `version.kind` / `version.between` 从下载地址识别 |
| `xml` | 从 XML 文档按字段路径和条件读取版本、下载地址与摘要 | 禁止声明 `version.from`；用 `itemsKey` / `match` 筛选父记录，再按 `version.key` 读取版本；特殊结构可用 XPath |
| `magnet` | 磁力链接（BitTorrent），交给 `FluxDown-CLI` 取包 | 禁止声明 `version.from`；用 `version.kind` / `version.between` 从文件名 `dn` 识别 |

`version.from` 写错取值会直接报错并列出可用值，不会静默回落。

**GitHub 走网页通道**：GitHub API 的匿名配额按出口 IP 计（同一 NAT 多机共享 60 次/小时）且常被企业网络拦截，因此 winst 只读 `releases/latest` 跳转、`releases` 列表页、`releases/expanded_assets/<tag>`、`releases/download/<tag>/<文件>`，不消耗配额、不需要令牌。发布列表（tag / 标题 / 正文 / 预发布标记）统一取自 `releases` 列表页，见下文 github 源。

### direct 源

```json
{
  "source": {
    "kind": "direct",
    "files": [{"url": "https://example.com/app-{version}.zip"}],
    "version": {"from": "page", "kind": "semver", "between": ["Version ", " "], "url": "https://example.com/download"}
  }
}
```

- `version.value` 指定固定版本；动态规则使用 `version.from`：`page` 从页面取版本，`package` 等取包，`header` / `json` 从独立版本地址取值。两类写法互斥；既无固定版本又无动态取版规则时明确报错。
- `version.from` 只接受 `page` / `package` / `header` / `json`；写别的值会报错。`page` 必须配 `version.url` 以及 `version.kind` / `version.between` 至少一项，无法识别即报错；`fetchWith` 可选 `iwr`（默认）/ `browser`。
- `source.version.package` 只能配合 `version.from: "package"`，写法见「包内版本派生」。
- 每个文件都必须写完整地址 `url`；只写文件名通配 `file` 无法定位。地址中的 `{version}` / `{versionMajor}` / `{versionMinor}` 无法展开为版本时即报错。
- 刷新时会探测主包地址一次；`404` / `410` 判为条目解析失败。

### github 源

```json
{
  "source": {
    "kind": "github",
    "repo": "ip7z/7zip",
    "files": [{"file": "7z*-x64.exe"}]
  }
}
```

`source.repo` 必填，`source.files` 至少一项。`files[]` 的定位方式二选一：

- `url` 可写完整地址，也可只写文件名（如 `"rufus-{version}.exe"`）→ 自动补全 `releases/download/<tag>/<文件名>`；逐个探测地址可用性
- `file` 使用[通用匹配规则](#通用匹配规则) → 读该发布的资产列表再匹配；无命中即报错，多命中取第一个并提示

**最新发布里没有所需文件时退回更早的发布。** GitHub 上常见「release 已建好、资产还在分批上传」：这时 `releases/latest` 指向的发布里还没有安装包，但上一次发布的文件是可用的。判定为「这个发布里没有要的文件」后，逐个试更早的发布，用第一个确实含有该文件的发布（最多查最近 5 个），并在结果的 `notes` 里写明「最新发布 x 里还没有这个文件，已改用更早的发布 y」。

候选与排序规则（都用网页通道，不消耗 API 配额）：

- **候选来自 `releases` 列表页**，保留 tag、标题、正文和 `Pre-release` 标记。
- **按版本号从高到低排，不按页面顺序**；初选与缺资产时的回退共用版本比较规则：相同数字版本的正式版高于预发布，预发布数字段按数值比较（`beta.10` 高于 `beta.2`），`+build` 不参与优先级。
- 只保留版本**严格低于**所选发布且能够比较版本的候选，不自动尝试更高版本或无法确定先后的发布。
- 未声明 `releaseTag` 且所选发布为正式版时，只回退正式发布；声明前缀或所选发布本身为预发布时，允许该范围内的预发布候选。

触发条件只有两种，都属于「这个发布里没有该文件」而非配置错误：

- `file` 匹配规则在该发布的资产列表里一个都没命中，或该发布还没上传任何资产
- `files[].url` **只写了文件名**（地址由 winst 拼成）且探测到 404

清单自己写了完整地址模板时（如 `https://…/download/v{version}/x.exe`）404 仍按配置错误直接报错，不退回旧版本——那通常意味着模板写错，静默安装旧版只会掩盖问题。`latestOnly: true` 可关闭整个回退逻辑。

`version.from` 的取值与约束：

| 取值 | 版本来自 | 约束 |
|---|---|---|
| `tag`（默认） | 发布 tag | 不能同时写 `version.kind` / `version.between`（那两个是从文件名识别版本的写法） |
| `file` | 下载文件名 | 必须写 `version.kind` 或 `version.between` 之一，否则报错 |
| `package` | 主包下载后读文件信息 | 不能写 `version.kind` / `version.between` |
| `releaseTitle` | 发布标题 | 必须写 `version.between` |
| `releaseBody` | 发布正文 | 必须写 `version.between` |

`releaseTag` 是 **tag 前缀**，用于把候选限定在该前缀的发布里（含预发布；在这些发布里按版本号取最高），适合一个仓库用不同前缀发布多条产品线的情况。前缀在生成版本号时会被去掉（`cli-v1.2.3` + 前缀 `cli-v` → 版本 `1.2.3`），因此 `{version}` 可直接用在 URL 模板里。不写则用 GitHub 自己认定的 `releases/latest`。

### listing 源

```json
{
  "source": {
    "kind": "listing",
    "indexUrl": "https://dlcdn.apache.org/maven/maven-*",
    "skipExistsCheck": false,
    "files": [
      {
        "url": "https://dlcdn.apache.org/maven/maven-{versionMajor}/{version}/binaries/apache-maven-{version}-bin.zip",
        "checksum": {
          "file": "https://dlcdn.apache.org/maven/maven-{versionMajor}/{version}/binaries/apache-maven-{version}-bin.zip.sha512",
          "format": "sha512"
        }
      }
    ],
    "version": {"kind": "semver", "filter": "preset:stable", "sort": "semver"}
  }
}
```

| source 字段 | 默认 | 约束 |
|---|---|---|
| `indexUrl` | 无 | 必填，可写字符串或字符串数组；多个列表页的版本候选合并后统一过滤与排序，目录通配规则见下文 |
| `version.kind` | 无 | 必填，只接受 `semver` / `date` / `digits` |
| `version.filter` | 不过滤 | 按[通用匹配规则](#通用匹配规则)过滤候选版本；`preset:stable` 接受 2～4 段纯数字版本及可选的单个 `v` / `V` 前缀、首尾空白 |
| `version.sort` | `semver` | `text` 按序号字符串从高到低排序，`semver` 按版本比较规则从高到低排序；其它取值报错 |
| `skipExistsCheck` | `false` | `true` 时不探测候选主包地址，直接采用排序后的首个候选 |
| `files` | 无 | 至少一项，只接受 `url`；主包可用版本模板，固定滚动地址要求过滤后只有一个版本候选 |

`indexUrl` 没有 `*` 时按原地址读取。有 `*` 时必须为绝对 HTTP(S) 地址，只允许最后一个路径段包含 `*`，末尾 `/` 可省略；主机名、父目录中含 `*`，或同时带查询串、片段的通配地址会报错。例如 `https://dlcdn.apache.org/maven/maven-*` 会先读取 `https://dlcdn.apache.org/maven/`，再匹配该层的 `maven-*` 子目录，不递归展开下一层通配。

目录发现接受相对或绝对链接，只保留同协议、主机与端口的直接子目录，链接必须以 `/` 结尾且没有查询串或片段；上级目录、跨站链接、深层路径和普通文件均跳过。匹配出的具体目录按完整 URL 区分大小写去重并保留首次出现顺序。没有匹配目录或父目录请求失败时，该索引地址记为失败；其它列表页仍有候选时会提示部分失败并继续，没有候选时解析失败并指出地址与原因。

`semver` 优先从列表页的直接子目录链接读取完整版本目录名，去掉单个 `v` / `V` 前缀，保留预发布和构建后缀，例如 `4.0.0-rc-7`；再执行 `version.filter`。已取得目录候选但过滤后为空时直接报错，不再次从整页文本提取数字。没有版本目录候选时按版本识别器扫描整页文本；这类数字扫描不保留预发布后缀，因此 `preset:stable` 只对完整版本目录候选提供严格的正式版筛选。`date` / `digits` 均按原识别器扫描整页文本。

候选经过滤与排序后，**从高到低逐个探测主包地址可用性**（上限 8 个候选），第一个非 404 的即采用；探测结果未知时会记提示并采用该候选。Maven 示例通过完整目录候选和 `preset:stable` 排除预发布，再用 `{versionMajor}` 同时展开安装包与 SHA512 地址，使正式版本不受固定主版本目录限制。

主包 URL 不含版本占位符时，列表必须专用于该滚动文件，且过滤后只有一个版本候选；多个候选会报无法确认文件对应版本，`skipExistsCheck` 不跳过此检查。目录同时列出多个文件日期时，应改用 `page`，从目标文件所在行截取日期，不能把全页最大日期当作它的版本。例如 Debian weekly ISO 可用 `link.text: "debian-testing-amd64-DVD-1.iso"`、`version.from: "page"`、`version.kind: "date"`、`version.between: ["debian-testing-amd64-DVD-1.iso</a>", "</tr>"]` 关联链接与同一行的日期。

### page 源

```json
{
  "source": {
    "kind": "page",
    "pageUrl": "https://www.microsoft.com/en-us/download/details.aspx?id=49117",
    "link": {"class": "dlcdetail__download-btn"},
    "files": [{"file": "*.exe"}],
    "fetchWith": "browser",
    "version": {"from": "url", "kind": "semver"}
  }
}
```

浏览器抓取与点击取址各自使用一次整体截止时间，覆盖启动、协议命令、页面等待、点击、读取和代理尝试；耗尽后停止后续点击并清理会话。导航错误、禁止下载设置失败、无法取得退出码或非零退出均不采纳页面内容。临时目录只有在重新查询确认对应浏览器进程已退出后才删除；清理失败保留目录并显示原因。

取址方式 `link` 与 `click` **二选一**（同时写会报错）：

| 字段 | 用途 | 约束 |
|---|---|---|
| `link` | 静态 HTML 里定位 `<a>`（相对地址按 `pageUrl` 解析为绝对地址） | 至少写一个条件（`class` / `id` / `text` / `href`）；空规则会命中第一个链接，因此被拒绝 |
| `click` | 下载地址由点击时的页面脚本生成时用；写法为步骤数组 | 省略 `fetchWith` 时自动使用浏览器；显式填写时只能为 `browser`，`iwr` 与点击取址冲突；每一步至少要一个条件 |
| `thenLink` | `link` 命中的是网页（中转页）时，再抓一层定位真实地址 | 必须搭配 `link`；不能与 `thenClick` 同用；需要 `thenLink.link`（中转页上的定位规则，至少写一个条件）或 `files[0].file`；显式写了空的 `thenLink.link` 时即使有 `files[0].file` 也会被拒绝 |
| `thenClick` | `link` 命中中转页后还要在浏览器里点按钮取址 | 必须搭配 `link`；不能与 `click` 同用；步骤数组每一步至少要一个条件 |
| `files[0].checksum.click` | `files[0].checksum.format: "page"` 就近刮取失败时，在同一无头会话里再点控件读可见摘要 | 必须搭配 `click` 或 `thenClick`，且主包 `checksum.format` 必须是 `page`；步骤写法与 `click` 相同；未声明时不做额外点击 |

`link` / `thenLink.link` / `click` / `thenClick` / `files[0].checksum.click` 的条件键只有 `class`、`id`、`text`、`href`。`class` / `id` / `text` 都是不区分大小写的子串匹配，`href` 使用[通用匹配规则](#通用匹配规则)；同一步写多个条件时必须全部满足。`source.link` 与 `thenLink.link` 的空对象 `{}`、所有条件都为空字符串，都会报 `source.link 至少要写一个条件` 或 `source.thenLink.link 至少要写一个条件`；`click` / `thenClick` / `files[0].checksum.click` 的任一步为空也同样报错。`click` 与 `thenClick` 实际执行都使用无头浏览器；`thenClick` 不必再单独声明 `fetchWith: "browser"`，但该值仍决定初始下载页和中转页的抓取方式。`files[0].checksum.click` 在取址成功拿到下载地址**之后**执行，不参与下载事件捕获——下载步骤仍写在 `click` / `thenClick` 里。

`link` 在下载页无命中时会检查 iframe；候选项经过 `files[0].file` 过滤后取第一个。使用 `thenLink` 时，若声明 `thenLink.link`，最终地址只由它筛选，`files[0].file` 不再参与第二次筛选；未声明 `thenLink.link` 时才用 `files[0].file` 过滤中转页全部链接并取第一个。

`version.from: "header"` / `"json"` 优先使用独立版本地址（见「独立版本地址」）；其中 `json` 的 `version.key` 指接口字段，不读取页面字段。其余取值与优先级：

1. `version.key`（页面数据里的字段名）直接读完整版本，不能与 `version.kind` / `version.between` 同写
2. `version.from: "page"` → 在页面 HTML 里按 `version.kind` / `version.between` 识别
3. `version.from: "url"`（默认）→ 在命中的下载地址里识别
4. 完全未声明版本字段与识别规则时可保留未知版本；声明的字段或规则取版失败时报错，不允许用条目固定版本兜底
5. `version.from: "package"` → 页面 / 地址都不找版本，等主包下载后取；此时不能再写 `version.key` / `version.kind` / `version.between`

`source.pageUrl` 必填。`files[0]` 是主包（只用于「挑哪一个」与校验）；第 2 条起是配套文件，写成带 `{version}` 的 `url` + `dest`。主包不能写 `url`（地址由页面提取），只能写 `file` 匹配规则（见[通用匹配规则](#通用匹配规则)）；主包 `dest` 忽略并提示。`skipExistsCheck` 默认 `false`，控制最终下载地址探测。

主包校验可用 `files[0].checksum.format: "page"`：默认按文件名在页面条目内就近刮取摘要（与 `digest` 相同边界）。若摘要只出现在需额外点击后的文案 / 弹层里（渲染 DOM 旁无安装包文件名），在 `click` / `thenClick` 之外再声明 `source.files[0].checksum.click`（步骤写法与 `click` 相同）；取址成功后同一无头会话按 `files[0].checksum.click` 点控件，再从可见文本中读取唯一的 32 / 40 / 64 / 128 位十六进制摘要。摘要尚未出现或暂时不唯一时会限时重试；等待结束仍无唯一摘要且就近提取失败时，报无法提取校验值。版本与就近摘要解析使用执行 `files[0].checksum.click` 前的页面快照。未声明 `files[0].checksum.click` 时不做任何额外点击，行为与「仅就近刮取」一致。

飞牛 fnOS 示例（下载点「直接下载」，摘要在「MD5」控件弹出的文案里）：

```json
{
  "source": {
    "kind": "page",
    "pageUrl": "https://fnnas.com/download",
    "fetchWith": "browser",
    "click": [{"text": "飞牛 fnOS"}, {"text": "X86"}, {"text": "直接下载"}],
    "files": [{"file": "fnos_*.iso", "checksum": {"format": "page", "click": [{"text": "MD5"}]}}],
    "version": {"kind": "semver"}
  }
}
```

### json 源

接口可以直接返回文件信息，也可以先返回目录索引，再读取选定的详情接口。`follow` 最多增加一次 GET；不声明时直接从 `apiUrl` 的响应解析发布与文件。

| source 字段 | 默认 | 约束 |
|---|---|---|
| `apiUrl` | 无 | 必填，初始 JSON 接口的固定地址；不支持 `{version}` / `{versionMajor}` / `{versionMinor}` / `{tag}` 占位符，写入会报错 |
| `follow` | 不跟随 | 可选对象，先从初始响应选择唯一索引项并读取下一接口；只接受下表列出的字段，所有字段值必须为字符串，不接受数组、JSON `null` 或嵌套 `follow` |
| `itemsKey` | 整个响应 | 发布对象或发布数组所在字段；相对于跟随后接口的响应，未声明 `follow` 时相对于初始响应；单对象作为一个候选 |
| `version.key` | 空 | 字符串，发布版本字段，相对于父发布对象；非空的 `version.filter` / `version.sort` 均要求它非空。未配置时按 `version.between` / `version.kind` 从最终主包 URL 识别版本 |
| `version.filter` | 不过滤 | 字符串，非空时对 `version.key` 取出的原始完整字符串应用[通用匹配规则](#通用匹配规则)，匹配前不去空白、不提取或规范化版本；必须配合非空 `version.key` |
| `version.sort` | 保留接口顺序 | 字符串，非空时只接受 `semver`，按版本比较规则选择最高版本的父发布，最高版本并列时报歧义；必须配合非空 `version.key`。排序接受去掉首尾空白后的完整单行版本形状，不执行严格 SemVer 格式校验 |
| `version.between` | 空 | 未声明 `version.key` 时，从最终主包 URL 按标记截取版本；与 `version.kind` 同写时先截取，再按识别器提取 |
| `version.kind` | 空 | 未声明 `version.key` 时，从最终主包 URL 或 `version.between` 截取后的文本按识别器取版本，取值见「版本标识器」 |
| `skipExistsCheck` | `false` | 是否跳过最终主包 URL 的存在性探测，不影响接口 GET |

`follow` 只从初始响应选择索引项，不使用主包的 `files[].match` / `file` 条件：

| follow 字段 | 默认 | 约束 |
|---|---|---|
| `itemsKey` | 整个初始响应 | 索引对象或索引数组所在字段；单对象作为一个候选 |
| `versionKey` | 空 | 索引项的版本字段；非空的 `versionFilter` / `sort` 及 `apiUrl` 中的版本占位符均要求它非空。用于索引选择与跟随地址模板，不作为软件最终版本 |
| `versionFilter` | 不过滤 | 非空时按通用匹配规则过滤索引版本的原始完整字符串，匹配前不去空白或规范化；必须配合非空 `versionKey` |
| `sort` | 不排序 | 非空时只接受 `semver`，选择最高版本的索引项，版本校验与 `source.version.sort` 相同；未配置时过滤后的候选必须恰好一个；最高版本并列同样报歧义 |
| `apiUrl` | 无 | 与 `urlKey` 必须二选一；完整详情接口地址，可使用 `{version}` / `{versionMajor}` / `{versionMinor}`，不接受 `{tag}` 或其它占位符。使用版本占位符时必须配合非空 `versionKey` |
| `urlKey` | 无 | 与 `apiUrl` 必须二选一；相对于选中的索引项读取完整详情接口地址，不对该字段值展开占位符 |

`follow.apiUrl` 和 `follow.urlKey` 取得的地址都允许跨域，必须为绝对 `http://` 或 `https://` URL；相对地址、本地路径、UNC 路径、其它协议和非法 URL 均报错。两字段必须只声明一个，同时声明即使其中一个为空也报错；声明值必须为非空字符串，不能写数字、数组、对象或 JSON `null`。

`follow.apiUrl` 中的 `{version}` 取首响应选中索引项的 `follow.versionKey`，先去首尾空白及单个 `v` / `V` 前缀；`{versionMajor}` / `{versionMinor}` 分别取该规范化版本按 `.` 切分的第一段 / 第二段；使用 `{versionMinor}` 时版本必须至少有两段，否则报错。字段缺失、值为空或无法作为完整版本使用时明确报错。跟随地址的版本与第二响应的 `source.version.key` 相互独立：前者决定请求哪个详情接口，后者决定最终软件版本。



所有字段路径支持点分嵌套与数字数组下标，例如 `products.0.url`。键名自身含点时用单引号包住该段：对象的单个键 `releases.json` 应写为 `"'releases.json'"`，嵌套文件名可写为 `files.'x.zip'.url`。本写法不支持数组条件表达式或通配查询。

`version.key`、`version.filter`、`version.sort` 和主包 `itemsKey` 配置值的首尾空白会去掉，空字符串按未配置处理；`checksum.fileMatch` 声明时须为非空字符串；声明时必须为字符串，不能写数字、数组、对象或 JSON `null`。`follow` 的所有字段也必须为字符串，其中所选地址字段 `apiUrl` 或 `urlKey` 不能为空。

主包 `files[0]` 的选择与版本归属：

- `urlKey` 必填；只写 `file` 无法定位地址，`url` 与 `urlKey` 互斥。`urlKey` 可配 `file`，按下载 URL 的文件名匹配候选。
- `files[0].itemsKey` 未配置时，父发布本身也是文件项。非空时从每个父发布的该字段取子文件数组或单个子文件；`match`、`file`、`urlKey`、`checksum.key`、`checksum.fileKey` 均相对于子文件，而 `source.version.key` 始终相对于父发布。
- 未声明 `version.sort`、`version.filter`、主包 `itemsKey` 时，按接口顺序采用第一个满足 `match` / `file` 且能读到 URL 的父项；只声明 `version.filter` 时先过滤父项，再按相同方式选文件。
- 声明 `version.sort: "semver"` 时先选唯一最高父发布，再选文件；该发布缺少目标文件、字段或有效下载地址即报错，不尝试较低版本。
- 配置非空主包 `itemsKey` 时必须先确定唯一父发布，再要求 `match` / `file` 恰好匹配一个子文件；没有排序且父发布不唯一，或子文件多匹配，均报歧义。
- `match` 是字段路径到期望文本的对象，所有条件都要满足，文本比较不区分大小写；它不使用通用匹配规则。`file` 使用通用匹配规则。
- 版本优先取父发布的 `version.key`；未写它时，从最终主包 URL 先按 `version.between` 截取，再按 `version.kind` 识别，完全未声明版本规则时可保留未知版本；声明规则但识别失败时报错，不能用固定版本兜底。
- `checksum.key` / `checksum.fileKey` 只在主包读取；摘要字段必须为 32 / 40 / 64 / 128 位十六进制，算法由摘要长度决定。第 2 项起的配套文件必须填写完整地址 `url`，不能使用 `urlKey` 或 `itemsKey`。
- `checksum.fileMatch` 只支持 `json` 主包，非空时必须配合非空 `files[0].itemsKey`，并与非空 `checksum.file` / `checksum.fileKey` 互斥。它在选中父发布的同一子文件集合中，用主包的 `urlKey` 读取每个子文件的地址，再按地址文件名应用通用匹配规则；必须恰好匹配一个校验文件，缺少匹配或匹配多个都报错；匹配出的地址必须为绝对 HTTP(S) 地址，否则报错。主包的 `match` / `file` 条件不参与校验文件筛选。
- `checksum.fileMatch` 取得的校验文件地址可配 `checksum.format`，默认 `sha256sums`；新 `checksum` 对象只选一种摘要来源，不能同时填写 `key` 与 `fileMatch`。接口只提供校验文件链接时，取得摘要需要额外 GET 校验文件。

启用版本过滤或排序时，缺少版本字段、版本为 JSON `null` 或空字符串的候选会被排除，排除后没有候选才报错；其余候选参与原文过滤与版本比较。没有启用过滤或排序但配置了非空 `source.version.key` 时，选中的发布缺少该字段或字段为空仍会报错。请求失败、响应不是合法 JSON、集合字段缺失、排序版本不是完整单行版本形状、跟随地址非法或候选歧义，也会使条目解析失败并指出步骤或字段。`follow` 不会把返回的 JSON 当成下一份 source 配置，也不会再次读取其中的跟随指令；请求使用现有 HTTP 代理和进程内缓存。

下面的完整 `source` 从微软发布索引选择最高正式版本，用其主版本展开详情接口地址，再按第二响应中的 `windowsdesktop.version` 选择最高正式发布的 Windows Desktop Runtime x64 安装器及官方摘要。索引与发布分别过滤，不使用固定数组下标；`preset:stable` 会排除 `preview` / `rc` 版本。

```json
{
  "kind": "json",
  "apiUrl": "https://builds.dotnet.microsoft.com/dotnet/release-metadata/releases-index.json",
  "follow": {
    "itemsKey": "releases-index",
    "versionKey": "latest-release",
    "versionFilter": "preset:stable",
    "sort": "semver",
    "apiUrl": "https://builds.dotnet.microsoft.com/dotnet/release-metadata/{versionMajor}.0/releases.json"
  },
  "itemsKey": "releases",
  "files": [
    {
      "itemsKey": "windowsdesktop.files",
      "match": {"rid": "win-x64"},
      "file": "windowsdesktop-runtime-*-win-x64.exe",
      "urlKey": "url",
      "checksum": {"key": "hash"}
    }
  ],
  "version": {"key": "windowsdesktop.version", "filter": "preset:stable", "sort": "semver"}
}
```

Graphviz 的 GitLab 最新发布接口同时提供版本和资产链接。主包与校验文件在同一 `assets.links` 集合中分别筛选，只选择 Windows Release 版 ZIP，排除 Debug 和 MSYS2 包；摘要从匹配的 `.sha256` 文件取得。

```json
{
  "kind": "json",
  "apiUrl": "https://gitlab.com/api/v4/projects/graphviz%2Fgraphviz/releases/permalink/latest",
  "files": [
    {
      "itemsKey": "assets.links",
      "urlKey": "url",
      "file": "windows_*_cmake_Release_Graphviz-*-win64.zip",
      "checksum": {"fileMatch": "windows_*_cmake_Release_Graphviz-*-win64.zip.sha256"}
    }
  ],
  "version": {"key": "tag_name"}
}
```

### xml 源

XML 源使用普通字段路径定位元素和属性，再用 `match` 筛选记录。下面的 `source` 先选 `platform-tools` 的正式频道包，再从包内选 Windows 归档；版本从父包读取，下载地址和摘要从归档读取：

```json
{
  "kind": "xml",
  "apiUrl": "https://dl.google.com/android/repository/repository2-1.xml",
  "itemsKey": "remotePackage",
  "match": {"@path": "platform-tools", "channelRef.@ref": "channel-0"},
  "baseUrl": "https://dl.google.com/android/repository/",
  "files": [
    {
      "itemsKey": "archives.archive",
      "match": {"host-os": "windows"},
      "urlKey": "complete.url",
      "checksum": {"key": "complete.checksum"}
    }
  ],
  "version": {"key": ["revision.major", "revision.minor", "revision.micro"]}
}
```

`@path` 表示 `path` 属性，`channelRef.@ref` 表示 `channelRef` 子元素的 `ref` 属性。`version.key` 数组按填写顺序读取各段，再用 `.` 连接；也可写单个字段路径，直接读取完整版本。每段都必须存在且唯一，缺段不会补零。

| source 字段 | 默认 | 约束 |
|---|---|---|
| `apiUrl` | 无 | 必填字符串，读取 XML 文档的固定绝对 HTTP(S) 地址；不支持 `{version}` / `{versionMajor}` / `{versionMinor}` / `{tag}` 占位符 |
| `itemsKey` | 无 | 与 `itemsXPath` 必须二选一；从 XML 根元素出发，按普通字段路径读取父记录候选，再按 `match` 筛选；结果必须唯一 |
| `match` | 不过滤 | 对象，键为候选父记录中的普通字段路径，值为期望字符串；只配合 `itemsKey` 使用，所有条件都必须满足 |
| `version.key` | 无 | 与 `version.xpath` 必须二选一；相对于选中的父记录，写非空字段路径字符串，或非空字符串数组；数组中每个路径必须读取到唯一非空文本，再用 `.` 连接 |
| `itemsXPath` | 无 | 高级写法，相对于 XML 文档选择唯一父记录；与非空 `itemsKey` 互斥，不能搭配 `source.match` |
| `version.xpath` | 无 | 高级写法，相对于父记录读取完整版本；与 `version.key` 互斥，可写节点路径或返回字符串的 XPath 表达式 |
| `baseUrl` | 空 = 未配置 | 解析相对下载地址时必填；非空时必须为末尾带 `/`、无查询串和片段的绝对 HTTP(S) 目录地址；XML 返回绝对 HTTP(S) 地址时直接采用 |
| `skipExistsCheck` | `false` | 是否跳过最终主包地址的存在性探测，不影响 XML 文档 GET |
| `files` | 无 | 至少一项；主包必须为含 `urlKey` 或 `urlXPath` 的对象；配套文件还可写字面地址或模板 `url`，支持通用文件属性 |

普通字段路径用 `.` 逐层读取子元素，不递归搜索；属性必须写成最后一段的 `@属性名`。`source.itemsKey` 从 XML 根元素起算，因此示例不需要在路径中写 `sdk-repository`；`files[].itemsKey` 从选中的父记录起算。元素和属性均按 `LocalName` 匹配，忽略命名空间前缀及默认命名空间，名称区分大小写。同名节点即使属于不同命名空间，也会一起参与匹配，最终仍须满足唯一性要求。

普通路径不接受空段、前后点、数组下标、`..`、引号段或 XPath 表达式，也不能填写命名空间前缀。路径名包含 `.` 或需要其它 XML 查询时，使用下方的 XPath 写法。

`source.match` 和 `files[].match` 都必须为对象，值必须为字符串。期望值与节点文本去首尾空白后按区分大小写的完整文本比较，不使用通配或正则规则；值只作为文本比较，不拼接进 XPath。条件字段缺失时排除该候选，字段匹配多个节点时直接报错；筛选结束后必须恰好保留一个候选，不按顺序取第一条、不挑最高版本，也不回退到其它频道或平台。

文件级取值范围与搭配：

- `files[].itemsKey` 可选，未配置时以父记录本身作为文件记录；配置后按该路径读取文件候选，再按本项 `match` 筛选唯一文件记录。它适用于主包和配套文件。
- `source.version.key` / `version.xpath` 始终相对于父记录；`files[].urlKey` / `urlXPath` / `checksum.key` / `checksum.xpath` 相对于本项选中的文件记录。示例中的 `revision` 属于父包，`complete` 属于 Windows 归档。
- 主包的 `urlKey` 与 `urlXPath` 必须二选一，配套文件也可用字面 `url`；`url`、`urlKey`、`urlXPath`、`file` 的定位方式互斥。XML 的 `urlKey` 不能配 `file`；JSON 主包的 `urlKey` + `file` 组合不受此限制。
- `checksum.key` 与 `checksum.xpath` 可选，非空时互斥；配置后必须读取到唯一非空的十六进制摘要，长度只接受 32 / 40 / 64 / 128，分别按 MD5 / SHA1 / SHA256 / SHA512 校验。不读取 XML 中的算法属性，也不需要 `checksum.format`。`checksum` 对象只选一种摘要来源，不能与固定值、校验文件或响应头混写。Android 示例的 `checksum` 按摘要长度识别为 SHA1。
- XML 返回相对下载地址时按 `baseUrl` 拼接，缺少基址即报错；最终地址必须为绝对 HTTP(S) 地址，本地文件、UNC 路径或其它协议均不接受。配套文件的字面 `url` 也可配 `baseUrl` 写相对地址，版本占位符按本文件版本展开，还可配 `versionListUrl` 独立取版，候选下载地址在展开版本并按 `baseUrl` 补全后探测；`urlKey` / `urlXPath` 文件不能配置 `versionListUrl`。

`apiUrl`、`itemsKey`、`itemsXPath`、`version.xpath`、`baseUrl`、文件项中的 `itemsKey` / `urlKey` / `urlXPath` / `checksum.key` / `checksum.xpath` 声明时必须为字符串；`version.key` 只接受字符串或非空字符串数组，数组每项均须非空字符串。数字、对象和 JSON `null` 不能代替这些字段。配置路径与 XPath 的首尾空白会去掉；必填项为空时报错，可选的文件 `itemsKey` / `checksum.key` / `checksum.xpath` 和 `baseUrl` 为空时按未配置处理。

版本文本去首尾空白与单个 `v` / `V` 前缀后必须为有效完整版本，不接受首尾点或连续点；读取失败时报错。普通路径读取版本的每个字段都要求唯一，避免组合版本时悄悄使用重复字段中的第一项。

特殊 XML 结构可直接使用 XPath。下面的配置片段使用同一 Android 仓库：保留上例的 `kind` / `apiUrl` / `baseUrl`，移除 `source.itemsKey` / `match` / `version.key`，改用这些高级字段：

```json
{
  "itemsXPath": "//remotePackage[@path='platform-tools' and channelRef/@ref='channel-0']/archives/archive[host-os='windows']",
  "files": [{"urlXPath": "complete/url", "checksum": {"xpath": "complete/checksum"}}],
  "version": {"xpath": "concat(../../revision/major, '.', ../../revision/minor, '.', ../../revision/micro)"}
}
```

XPath 使用 .NET 的 XPath 1.0 规则，不使用通用匹配规则，也不展开版本占位符。`itemsXPath` 必须返回唯一节点；值表达式返回节点集时必须恰好包含一个节点，返回字符串时直接取值，数字和布尔结果不接受。值会去首尾空白，缺失、空值、多匹配或非法表达式均报错。字符串表达式内部的参数按 XPath 规则取值，不检查每个参数路径是否唯一。未绑定自定义命名空间前缀；需要显式处理命名空间时可用 `local-name()`，例如 `*[local-name()='complete']/*[local-name()='url']`。

普通路径与 XPath 可以按字段组合，但同一用途的两种写法不能同时配置：`itemsKey` / `itemsXPath`、`version.key` / `version.xpath`、`urlKey` / `urlXPath`、`checksum.key` / `checksum.xpath` 分别互斥。使用 `itemsXPath` 时不能再配 `source.match`；文件筛选仍可使用普通 `itemsKey` / `match`。

XML 请求使用现有 HTTP 代理与进程内缓存。XML 格式非法、文档含 DTD 或外部实体、筛选不唯一、字段缺失、版本或摘要无效、地址非法，都会明确报错。主包地址探测的 `404` / `410` 与网络结果未知处理沿用通用规则。

### magnet 源

```json
{
  "source": {
    "kind": "magnet",
    "files": ["magnet:?xt=urn:btih:0123456789abcdef0123456789abcdef01234567&dn=demo-1.2.3.zip"],
    "version": {"kind": "semver", "between": ["v", " "]}
  }
}
```

- `source.files` 至少一项；地址必须是完整磁力链接（`magnet:` 开头）；不接受 `{version}` / `{versionMajor}` / `{versionMinor}` / `{tag}` 占位符
- 只有声明 `version.kind` 或 `version.between` 时才从文件名（`dn` 参数）识别；两者同写时先按 `version.between` 截取，再按 `version.kind` 识别。未声明规则时可保留未知版本；声明规则但识别失败时报错，不允许声明固定版本兜底
- 文件大小从 `xl` 参数取；`files[].name` 可覆盖文件名，未写时用 `dn`
- 交给 `FluxDown-CLI`（下载引擎）以 BitTorrent 任务取包

## 版本号处理

### 独立版本地址（direct / page）

`source.version.from` 在 `direct` / `page` 中支持 `header` / `json`，将版本获取与下载地址解析分开。固定 `version.value` 与这些动态规则互斥。

| source 字段 | 默认 | 约束 |
|---|---|---|
| `version.url` | 无 | 两种方式都必填，完整版本地址；不支持 `{version}` / `{versionMajor}` / `{versionMinor}` 占位符 |
| `version.header` | 无 | `header` 必填；向 `version.url` 发 HEAD，按不区分大小写的响应头名取值 |
| `version.key` | 无 | `json` 必填字符串；向 `version.url` 发 GET，将响应解析为 JSON，按字段路径读取一个版本值或版本数组；支持点分路径和数组下标，如 `0.version`；数组项本身就是版本值，不需要另写字段名 |
| `version.filter` | 不过滤 | 仅 `json` 读取；非空字符串时，对版本值的原始完整字符串应用[通用匹配规则](#通用匹配规则)，过滤前不去空白、不提取或规范化版本；必须配合非空 `version.key` |
| `version.sort` | 不排序 | 仅 `json` 读取；非空时只接受字符串 `semver`，按版本比较规则选择唯一最高版本；必须配合非空 `version.key` |

JSON 取值可为单个版本，也可为版本数组。候选先按 `version.filter` 过滤，再按 `version.sort` 排序；最终必须恰好剩下一个版本。多个候选没有配置排序或过滤后仍有多个时会报错；排序的最高版本对应多个候选也会报歧义，不取首项、不按数组顺序猜最新版本。排序前要求版本去掉首尾空白后是完整单行版本形状，不执行严格 SemVer 格式校验。

`version.key`、`version.filter` 和 `version.sort` 配置必须为字符串，不能写数字、数组、对象或 JSON `null`；配置值会去首尾空白，空的 `version.filter` / `version.sort` 按未配置处理。过滤作用于接口返回的原始完整版本字符串，之后才去版本首尾空白与单个 `v` / `V` 前缀。启用过滤或排序时，数组内为 JSON `null` 或空字符串的候选会被排除；没有可用候选时明确报错。

请求失败、JSON 非法、字段或响应头缺失、最终版本为空或无效，以及筛选没有唯一结果时，条目解析失败，不回退其它来源版本。`header` 不能声明 `version.filter` / `version.sort`。独立版本请求使用 HTTP 通道的代理和进程内缓存；page 的 `fetchWith` 仍只控制下载页面抓取。不能声明 `version.kind` / `version.between`；这两种方式直接使用头或字段的完整版本值。`source.version.package` 只允许配合 `version.from: "package"`。

下面的 `source` 从 NuGet 的版本数组中选出最高正式版，再按主次版本与完整版本展开安装器地址。`preset:stable` 排除 `preview` / `experimental`，接受 2～4 段纯数字版本及可选的单个 `v` / `V` 前缀、首尾空白；例如 `2.6.5` 展开为 `2.6/2.6.5`：

```json
{
  "kind": "direct",
  "files": [
    {
      "url": "https://aka.ms/windowsappsdk/{versionMajor}.{versionMinor}/{version}/windowsappruntimeinstall-x64.exe"
    }
  ],
  "version": {
    "from": "json",
    "url": "https://nuget.azure.cn/v3-flatcontainer/microsoft.windowsappsdk/index.json",
    "key": "versions",
    "filter": "preset:stable",
    "sort": "semver"
  }
}
```

响应头取版使用 `version.header`：

```json
{
  "kind": "direct",
  "files": [{"url": "https://persistent.oaistatic.com/codex-app-prod/ChatGPT-x64.msix"}],
  "version": {
    "from": "header",
    "url": "https://persistent.oaistatic.com/codex-app-prod/ChatGPT-x64.msix",
    "header": "x-ms-meta-package_version"
  }
}
```

### 占位符

| 占位符 | 展开为 | 可用位置 |
|---|---|---|
| `{version}` | 本次解析出的版本；`source.follow.apiUrl` 使用首响应选中项的版本 | `source.follow.apiUrl`、`files[].url` / `file` / `name` / `checksum.value` / `checksum.file` / `versionListUrl`、`postInstallCopy.from` / `to`、`postInstall` / `uninstall.commands` 的 `exe` / `args`、`installArgs` / `uninstall.args` / `installerExe`、`uninstall.name`、`mainExe`、`keep`、`env` 的值、`addToPath`、`detect.name` / `versionKind` / `pathGlob` / `jsonKey` / `versionArgs` / `exe` |
| `{versionMajor}` | 版本号按 `.` 切分的第一段（`2.57.1` → `2`） | 同上 |
| `{versionMinor}` | 版本号按 `.` 切分的第二段（`2.6.5` → `6`）；版本不足两段时报错，不补零 | 同上 |
| `{tag}` | GitHub release tag（按 URL 路径段转义） | github 源的 `files[].url` / `file` |
| `{urlQuery:参数名}` | 本文件下载地址查询串里该参数的值 | `files[].checksum.file` |
| `{installDir}` / `{installRoot}` | 实际路径 | `installArgs`、`env`、`addToPath`、`postInstall`、`uninstall.commands`、`detect.pathGlob` / `detect.exe`；`postInstallCopy` 只按安装目录内的相对路径使用 |
| `%VAR%` | `env` / `addToPath` 中原样写入；执行命令前展开 | `env` / `addToPath` / `postInstall` / `uninstall.commands` |

`files[].file` 中的版本占位符只适用于已取得版本的 github 源；page / json 在识别主包版本前就需要匹配文件，因此主包 `file` 应使用固定文字和通配符。正则规则中的版本值按字面量转义，`{versionMajor}` / `{versionMinor}` 与 `{version}` 遵循相同规则。

使用版本占位符时必须已取得相应版本；版本未知时报错，不替换为空串。`direct` 即使跳过存在性探测，各文件展开后的 URL 也必须是绝对 HTTP(S) 地址。文件名去首尾空白后用于重复检查与缓存落盘，大小写不同的同名文件也算重复。`{urlQuery:参数名}` 按参数名精确区分大小写，同名参数重复时取首值；保留值的百分号编码（如 `%26`、`%2B`、`%25`），不解码为 URL 结构字符，也不二次编码；替换值作为字面文本插入，不再解释其内部占位符。

`{installDir}` 与 `%VAR%` 的区别很重要：前者是 winst 自己的路径，后者是对其它环境变量的引用（如 `%JAVA_HOME%\bin`），在 `env` / `addToPath` 中保留下来才能在用户切换版本时自动跟随。

`installArgs` 未写在双引号内的 `{installDir}` / `{installRoot}` 会自动按单个参数加引号；仅展开原模板的占位符，插入路径中的花括号按字面保留。`postInstall` / `uninstall.commands` 的展开顺序是先展开 `%VAR%`，再替换 `{installDir}` / `{installRoot}`；版本占位符在来源解析阶段已经展开。

### 版本标识器

来源使用 `source.version.kind`；检测与包内派生使用 `versionKind`。这些位置共享以下三种识别器：

| kind | 匹配 | 例子 |
|---|---|---|
| `semver` | `1.2` / `1.2.3` / `1.2.3.4`，可带 `v` 前缀 | `v24.9.0` → `24.9.0` |
| `date` | `2026-09-07` / `2026.09.07` / `20260907` | |
| `digits` | 2 位以上纯数字 | `20326` |

来源的 `source.version.between`，以及检测与包内派生的 `versionBetween`，写成 `[ "前缀", "后缀" ]`；后缀可省略为 `[ "前缀" ]`，表示取到文本末尾。空数组仅在允许该字段的位置按未配置处理；非空数组的前缀不能为空，数组不能多于两项；标记按字面量、区分大小写查找。它适合版本号夹在固定文本里的场合（`["Temurin-", " "]`）。

direct / page 的版本文本识别先按 `version.between` 截取，再按 `version.kind` 提取；两者都没写时不从任意文本猜版本，由该来源的其它有效规则提供版本；page 完全无版本规则时可保留未知版本。github 的 `file` / `releaseTitle` / `releaseBody` 及 detect 使用同一截取与识别组合。json / magnet 也使用先截取、再识别的同一顺序。`source.version.package` 两个识别字段都不写时才取第一个像版本号的字符串；detect 的无识别规则兜底见「版本检测」。

### 版本改写（`rewrite` / `versionRewrite`）

把上游的版本写法归一成本地比较 / 展示用的写法。三种等价写法，**一条规则只能用一种**，多条写成数组按顺序应用：

```json
[
  {"from": "jdk8u{u}-b{b}", "to": "1.8.0_{u}-b{b}"},
  {"stripPrefix": "jdk-"},
  {"stripSuffix": "-beta"},
  {"pattern": "^v", "replace": ""}
]
```

- 模板写法的 `{占位符}` 在 `from` 与 `to` 里同名对应；`to` 写空串 `""` 表示整段去掉
- 正则写法的 `replace` 沿用 .NET 正则替换语法（`$1` / `${name}` 引用捕获组）
- 单条规则匹配不上时保持原值；规则不保证幂等，只对相应阶段的原始读数应用一次
- 声明了但没有任何有效规则、或一条规则里混用多种写法，清单报错

三处作用域，用途互不重叠：

| 位置 | 作用对象 |
|---|---|
| `source.version.rewrite` | 源侧解析出的版本（tag / 文件名 / 页面 / 接口 / 包内信息） |
| `detect.versionRewrite` | 本机检测出的版本（`registry` / `fileVersion` / `cliVersion` 等全部检测方式） |
| `files[].versionRewrite` | 作用于该文件下载声明的版本占位符，不改写软件整体版本 |

来源与本机检测各自需要归一时，分别声明对应规则。下载地址、文件名及校验声明在来源解析阶段使用该文件的版本展开；计划中的 `mainExe`、`detect`、复制和命令字段使用来源归一后的软件版本展开。`{tag}` 始终使用发布 tag。来源发生版本改写时，改写前的值保存在解析锁的 `sourceVersion`。

缓存索引和安装台账存放已归一的版本，展示或从索引恢复版本时不再次应用来源规则。修改规则不会自动迁移既有索引版本，需要通过重新取包确认新读数。

### 版本比较规则

1. 去 `v` 前缀与首尾空白。
2. 所有写法均忽略 `+` 后的构建元数据，不因另一侧是否严格 SemVer 而改变规则。
3. 核心按数字串 / 字母串切分，分隔符忽略；数字段按数值比，文字段不区分大小写；缺段补 `0`（`1.0` = `1.0.0`，`1.8.0_504` = `1.8.0.504`）。
4. `-` 后的预发布后缀低于同核心正式版；后缀按点分标识比较：数字按数值且低于文字，文字区分大小写，标识前缀相同时较短者低。

## 摘要对象（`source.files[].checksum`）

不声明表示没有作者提供的摘要规则；声明对象时必须选择且只选择一种来源：`value`（固定摘要）、`header`（响应头）、`key`（接口字段）、`xpath`（XML 表达式）、`file`（校验文件地址）、`fileKey`（接口中的校验文件地址字段）或 `fileMatch`（同一接口文件集合里的校验文件）。这些选择字段都必须是非空字符串。

`format` 只与 `file` / `fileKey` / `fileMatch` 搭配，默认 `sha256sums`。页面摘要是例外：只写 `format: "page"`，不再填写任何来源选择字段；可配 `click`，但仅适用于 page 主包且需要下载取址使用 `click` 或 `thenClick`。

```json
{
  "checksum": {"file": "https://example.com/demo-1.2.3.zip.sha512", "format": "sha512"}
}
```

展开占位符后，固定摘要、响应头与接口取出的摘要必须是 32 / 40 / 64 / 128 位十六进制，分别代表 MD5 / SHA1 / SHA256 / SHA512；不接受其它长度或非十六进制字符。全部字段及适用位置见下一节。

### 主包与配套文件适用范围

| 配置 | 主包 `files[0]` | 配套文件 `files[1...]` |
|---|---|---|
| `url` / `file` | 由来源 kind 决定；page 只从页面取地址 | direct / github 可用对应定位方式；listing / page / json 用 `url`；xml 还可用接口字段 |
| `itemsKey` / `match` / `urlKey` | JSON 与 XML 可用，作用域见各来源 | 仅 XML 可用；JSON 附件不读取这些字段 |
| `urlXPath` / `checksum.xpath` | 仅 XML | 仅 XML |
| `checksum.key` | JSON / XML | 仅 XML |
| `checksum.fileKey` / `checksum.fileMatch` | 仅 JSON；`fileMatch` 需要非空 `itemsKey` | 不适用 |
| `checksum.format: page` / `checksum.click` | 仅 page | 不适用 |
| `checksum.value` / `checksum.file` | 按来源的下载与校验规则使用 | 同左 |
| `checksum.header` | HTTP 来源；magnet 不支持 | HTTP 来源；magnet 不支持 |
| `dest` / `extract` / 文件级 `stripTopDir` | 不控制主包落位，主包使用条目级规则 | 非 installer 的安装流程使用；`extract` 时 `dest` 必填且为目录 |
| `versionListUrl` / 文件级版本识别 | 不适用 | 仅 listing / page / json / xml 的 `url` 附件，可独立选择版本 |
| `refresh` / `compare` / `maxAgeHours` | 控制本文件缓存复用 | 控制本文件缓存复用，不继承主包声明 |

GitHub 需要检索发布列表（前缀筛选、元数据或旧发布回退）时只读取近期发布的前两页；未命中表示该检索范围内没有目标，不能据此断言仓库全部历史中不存在。按版本推断 tag 的候选请求不改变此检索范围。

### 不同来源怎样选记录

| 来源 | 候选选择 | 找不到目标文件时 |
|---|---|---|
| listing | 过滤后按版本或文本从高到低选候选 | 在规定数量内探测较低版本，非 404 的首个候选可用 |
| JSON | 简单扁平响应默认取第一个合适项；`version.sort` 选择唯一最高父发布；非空文件 `itemsKey` 要求唯一父发布与唯一子文件 | 选定最高父发布后缺文件即报错，不尝试低版本 |
| XML | `itemsKey` + `match` 或 XPath 必须选出唯一父记录；文件记录也必须唯一 | 无匹配或多匹配均报错，不按顺序取首个，不自动挑最高版本 |

page 的架构筛选应把架构词限定到文件名，避免被目录中的 `x64` 命中而选到另一架构文件。

JSON 的 `match` 按不区分大小写的完整文本比较；XML 的 `match` 按去首尾空白后的区分大小写完整文本比较。两者都不使用通用匹配规则；需要按下载文件名通配筛选 JSON 主包时使用 `file`。

## 文件级属性

主包是 `source.files[0]`，第 2 项起是配套文件。下表列出字段，适用范围并不相同：

| 字段 | 默认 | 说明 |
|---|---|---|
| `url` | — | 下载地址或地址模板 |
| `file` | — | 文件名匹配规则，见[通用匹配规则](#通用匹配规则)；page 同时匹配完整 URL 和文件名 |
| `urlKey` | — | `json` 主包或 `xml` 文件：存放下载地址的字段路径；XML 相对于本项选中的文件记录，结果必须唯一非空；与 `urlXPath` 互斥 |
| `urlXPath` | 空 = 未配置 | 仅 `xml`：相对于本项文件记录读取下载地址的 XPath，与 `urlKey` 互斥；主包必须选择其一，配套文件还可写 `url`；结果须唯一非空，相对地址必须配 `source.baseUrl`，详见「xml 源」 |
| `itemsKey` | 父记录本身 | 字符串；`json` 仅主包可用，相对于父发布取子文件数组或对象；`xml` 主包和配套文件均可用，相对于父记录取子文件节点，再按本项 `match` 筛选；父记录与最终匹配文件均须唯一，详见对应来源 |
| `dest` | 空 = 仅缓存，不落位 | 配套文件的相对落位路径（不能为绝对路径、`.` 或含 `..`）；普通文件填写目标文件名（如 `config.ini`），`extract: true` 时必须填写解压目标目录，否则安装时报错；主包上的 `dest` 忽略并提示 |
| `extract` | `false` | 该文件是压缩包，安装时解压到 `dest`（仅配套文件） |
| `stripTopDir` | `false` | `extract` 时该压缩包自己的剥壳设置 |
| `name` | 空 = 从地址或来源推导 | 下载产物文件名（地址里带不出文件名时用；magnet 源也可覆盖 `dn`）；github 的 `file` 使用实际资产名。同一条目的全部下载产物必须使用不重复的文件名（Windows 不区分大小写），否则报「下载文件名重复」。下载引擎按单层文件名使用它：不能含 `\` / `/`、`.` / `..`、保留设备名或超过 100 字符，规划时无法使用会报「下载信息不完整（文件名不合法或地址为空）」 |
| `checksum.header` | 无；选用时须非空 | HTTP 来源可用，magnet 不支持。对最终下载地址发 HEAD，以指定响应头作为摘要；与其它摘要来源互斥，不能配校验文件格式。响应头必须是非空十六进制摘要，长度只接受 32（MD5）/ 40（SHA1）/ 64（SHA256）/ 128（SHA512）；请求失败、缺头或格式非法时条目解析失败。解析结果保存取得的摘要，下载后按该摘要校验；package 来源用此摘要与本地包实际摘要判断远端有无新包，本地缺包时无法比较。已存在包按摘要一致复用、不一致重取，不因地址变化强制重取 |
| `checksum.value` | 无；选用时须非空 | 固定摘要。算法由长度推断：32 → MD5，40 → SHA1，64 → SHA256，128 → SHA512；长度必须为 32 / 40 / 64 / 128 且内容为十六进制；不能与其它摘要来源混写 |
| `checksum.file` | 无；选用时须非空 | 外部校验文件的地址；与 `checksum.format` 搭配；`format` 需要校验文件来源；页面摘要使用独立的 `format: "page"` 写法 |
| `checksum.format` | 校验文件默认 `sha256sums` | 校验值的提取方式，见下方枚举；`checksum.fileKey` / `checksum.fileMatch` 取得的地址同样适用 |
| `checksum.key` | 无；选用时须非空 | `json` 主包或 `xml` 文件的摘要字段路径；相对于选中的文件项。JSON / XML 均要求 32 / 40 / 64 / 128 位十六进制；XML 还必须唯一非空，并与 `checksum.xpath` 互斥；实际算法由摘要长度决定 |
| `checksum.xpath` | 无；选用时须非空 | 仅 `xml`：相对于本项文件记录读取摘要的 XPath，与 `checksum.key` 互斥；结果须唯一非空，必须为 32 / 40 / 64 / 128 位十六进制，分别对应 MD5 / SHA1 / SHA256 / SHA512；不能与其它摘要来源同写 |
| `checksum.fileKey` | 无；选用时须非空 | 仅 `json` 主包：文件项里校验文件地址的字段名；声明 `itemsKey` 时相对于子文件，字段缺失即报错，可配 `checksum.format` |
| `checksum.click` | 不额外点击 | 仅 page 主包的 `format: "page"`；条件步骤数组，字段与页面 `click` 相同；必须搭配 `source.click` 或 `source.thenClick`，与兼容的 `source.hashClick` 互斥 |
| `checksum.fileMatch` | 无；选用时须非空 | 仅 `json` 主包：字符串，去首尾空白后非空时必须配非空 `itemsKey`，与非空 `checksum.file` / `checksum.fileKey` 互斥；在选中父发布的同一子文件集合中，用本项 `urlKey` 取得地址并按通用文件名规则选择唯一校验文件；无匹配或多匹配报错。可配 `checksum.format`，默认 `sha256sums`；不能与其它摘要来源同写 |
| `match` | 不过滤 | 对象，按文件项字段路径比较期望文本，所有条件都必须满足，不使用通用匹配规则。JSON 仅主包可用，比较不区分大小写；XML 主包与配套文件均可用，键为普通字段路径、值必须为字符串，去首尾空白后区分大小写比较，缺字段排除候选，多节点报错 |
| `refresh` | 未声明 | 先按文件自己的版本复用；显式 `auto` 则执行摘要 / HTTP 新鲜度判定，两者不等价，见下方枚举 |
| `maxAgeHours` | `168` | `ttl` / `auto` 的 TTL 兜底；声明时必须为正整数，非法值报错 |
| `compare` | `auto`（无摘要时比较最后修改时间 + 大小） | 远端文件的比对判据，见下方枚举；空值按 `auto`；无法识别的词报错 |
| `versionListUrl` | 空 | 该配套文件独立去版本列表页找最新版（不跟随主包版本节奏）；只支持 `url` 模板定位的文件 |
| `versionKind` | 空 = 用 `source.version.kind` | 配合 `versionListUrl` 收集候选；此时本文件或 source 层必须至少写一处。来源版本规则不允许 `kind` 时（如 XML 或 JSON 已使用 `version.key`），须在配套文件上显式填写 `versionKind` |
| `versionFilter` | 空 | `versionListUrl` 的候选过滤，见[通用匹配规则](#通用匹配规则) |
| `versionRewrite` | 空 | 只作用于该文件的地址模板展开与文件版本记录，不影响主包和其它文件 |

`url`、`urlKey` 分别与 `file` 互斥；`url` 与 `urlKey` 也互斥，同时写会报错。**例外是 json 主包的 `urlKey` + `file`，这是允许且常用的组合**：前者定位接口字段，后者筛选候选条目。`urlKey` 只用于 `json` / `xml` 源；`urlXPath` 只用于 `xml` 源，并与同一文件的 `url` / `urlKey` / `file` 互斥。XML 的 `urlKey` 不能搭配 `file`。page 主包不能写 `url`，只能写 `file`；xml 主包必须写 `urlKey` 或 `urlXPath`；各来源具体必填组合见前文。

`versionListUrl` 的列表页地址可用主包版本展开 `{version}` / `{versionMajor}` / `{versionMinor}`；候选经 `versionFilter` 后按版本从高到低探测最终文件地址，上限 8 个，第一个非 404 的采用，`source.skipExistsCheck` 可关闭探测。它只适用于 listing / page / json / xml 第 2 项起的 `url` 配套文件；direct 不读取它，主包、json 的 `urlKey` 地址和 xml 的 `urlKey` / `urlXPath` 地址不能使用。xml 中 `urlKey` 或 `urlXPath` 与 `versionListUrl` 同时配置会报错。github 的 `url` 项不读取它，`file` 项虽会进入独立列表解析，但随后仍因定位不是 `url` 而报错，所以 github 条目不要使用 `versionListUrl`。

`checksum.format` 的全部取值：

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
| `digest` | 按完整文件名字段或链接路径中的文件名匹配，在同一文本行或 HTML 条目内取后面最近的摘要；不接受其它文件名的前后缀命中。表格按整行处理，遇到另一安装包文件名停止。长度 32 / 40 / 64 / 128 分别为 MD5 / SHA-1 / SHA-256 / SHA-512；没有摘要或同一文件对应多个不同摘要时报错 |
| `re:<正则>` | 自定义正则提取，命名组 `h` 或第 1 捕获组 |
| `page` | 仅 `page` 源、仅主包：优先按 `digest` 相同的条目边界就近提取摘要；就近失败且声明了 `source.files[0].checksum.click`（须搭配 `click` 或 `thenClick`）时，取址会话再按 `checksum.click` 点控件，并从可见文案读取唯一的 32 / 40 / 64 / 128 位十六进制摘要。未声明 `checksum.click` 时不额外点击。不能与 `checksum.value` 同写 |

未显式声明 `refresh`，且 `compare` 也未声明或为默认 `auto` 时，安装与仅下载操作均优先比较远端版本和该文件缓存记录的 `sourceVersion`：版本相同复用，版本不同重取，不受地址或 HTTP 校验器漂移影响。只有**这个文件自己的版本**参与该判定：主包恒有；配套文件仅当声明 `versionListUrl` 并独立解析出版本时才有，其余跟随主包版本的配套文件不记录也不比较版本。两侧任一版本缺失、或版本仅来自尚未确认新鲜度的缓存包时，继续按地址、摘要与新鲜度规则判定；地址按完整字符串区分大小写比较，包括路径与查询参数。声明的摘要仍须满足校验规则；显式比较项不会被同版本快捷命中绕过。

`refresh` 的全部取值（大小写、`-` 与 `_` 不敏感；空值或无法识别的值报错）：

| 取值 | 行为 |
|---|---|
| `auto` | 有摘要按摘要比对；无摘要时联网确认一次（`compare` 判据）；都拿不到时退到 TTL 兜底 |
| `always` | 每次都重新下载 |
| `ifMissing` | 地址与缓存记录一致且文件存在时复用，不做新鲜度确认 |
| `check` | 必须靠校验器 / 摘要确认；拿不到校验信息就重取，不做 TTL 兜底 |
| `ttl` | 距上次确认未超 `maxAgeHours` 则命中，否则联网确认一次 |

`compare` 的全部取值（大小写、`-` 与 `_` 不敏感；可用 `,` / `;` / `|` / 空白分隔组合，只比列出的项）：

| 取值 | 行为 |
|---|---|
| `auto`（默认） | 比 `Last-Modified` + 文件大小（记录里有哪项比哪项）。`ETag` 在不少主机上阶段性漂移，不作为默认判据 |
| `size` | 只比文件大小——主机 `Last-Modified` 也会漂移时用（如 `dl.google.com`） |
| `etag` | 比 `ETag`；需要按主机提供的实体标识判断时显式写 |
| `lastModified` | 比 `Last-Modified`；别名 `lm` |
| `checksum` | 强制重取远端校验文件（`checksum.file`）并与本地比对的判据；别名 `hash` / `fingerprint`。地址固定的 `checksum.file`（不随版本变化）只有写它才能发现远端换了文件。该文件未声明 `checksum.value` / `checksum.file` 时忽略这一项并提示 |

组合示例：`"compare": "lastModified,size"` 选择与无摘要时 `auto` 相同的字段，但显式写法要求执行比较；`"compare": "etag,size"` 选择 ETag 与大小。声明 `checksum.value` / `checksum.file` 时仍先校验摘要：默认 `auto` 在摘要一致后直接复用，显式 HTTP 判据则继续组合比较；`checksum.file` 默认可复用与当前声明指纹匹配的缓存期望摘要，只有显式 `checksum` 才强制重取校验文件。能够取得的判据中任一变化即重取，一个都无法比较时按 `refresh` 的失败/TTL 策略处理，未成功确认不会刷新确认时间。任一无法识别的词都会使条目解析失败，不丢弃拼错的比较条件。

安装包下载后，`winst.json` 同时保存远端期望摘要 `expectedHash` 和本地计算摘要 `hashes` / `manifestHashes`。校验声明指纹匹配时可以复用远端期望摘要；普通安装、引擎引导和自更新在实际使用缓存包前仍重算当前文件摘要并比对。在线发现不一致则重新下载，离线则保留原文件并报错；缺少匹配的远端期望摘要时需联网补取，离线明确报错。列表与更新检查可以沿用历史摘要判断缓存状态。

期望摘要来自清单或缓存索引；同时修改文件与其期望摘要的人仍可伪造一致的结果。未声明校验的包按新鲜度规则处理。详细格式和复用条件见 [缓存索引](data-files.md#winstjson缓存索引)。

## 命令条目

`postInstall` 与 `uninstall.commands` 共用同一结构：

| 字段 | 默认 | 说明 |
|---|---|---|
| `exe` | 必填 | 可执行文件；相对路径按安装目录解析，支持 `{installDir}` / `{installRoot}` / `{version}` 与 `%VAR%`；缺少或空白 `exe` 时，清单解析报含规则下标的字段错误，路径含双引号或控制字符、文件不存在时执行失败 |
| `args` | 空 | 命令行片段（允许带引号）；不允许换行等控制字符 |
| `timeoutSec` | `600` | 超时秒数；超时按进程树结束并判为该步失败；声明时必须为正整数，非法值报错 |
| `requireAdmin` | `false` | 为真时先检查当前进程是否管理员，不是则明确报错、不执行 |

`postInstall` 的退出码不是 `0` / `1641` / `3010` 即安装失败（后两者表示已发起重启 / 需重启才能完成）。`uninstall.commands` 在**删目录 / 跑官方卸载器之前**执行（如 `regsvr32 /u` 注销滤镜时文件还在原地），失败即中止卸载，`--force` 跳过。

## 版本检测（`detect`）

`detect.method` 决定怎么读本机已装版本。**全部取值**：

| `method` | 版本来源 | 该方式用到的字段 | 说明 |
|---|---|---|---|
| `none`（默认，`installer` 除外） | 不检测 | — | 每次都按未安装处理 |
| `registry` | 系统卸载记录（HKLM / HKCU 的 `Uninstall` 键） | `name` | `installer` 未声明 `detect` 时的默认值，`name` 自动生成为 `*<name>*` |
| `fileVersion` | 文件的版本资源 | `pathGlob` | 取 `FileVersion` / `ProductVersion`；无有效字符串且数值体全零时视为没有版本资源，明确声明的零版本仍有效；字符串与数值体不一致时以数值体为准（除非字符串是它的数字前缀） |
| `markerFile` | 标记文件的内容 | `pathGlob` | 文件内容常就是版本号本身 |
| `jsonFile` | JSON 文件里的字段 | `pathGlob`、`jsonKey` | 从 `pathGlob` 命中的文件里取 `jsonKey` 字段 |
| `appx` | 系统应用包记录 | `name` | 按包名规则匹配；检测使用单条字符串规则，卸载规则才可为数组 |
| `cliVersion` | 运行程序取版本 | `exe`、`versionArgs` | `exe` 未写时用 `mainExe`；程序必须把版本写到 stdout / stderr（直接写控制台的拿不到） |

`detect.name` 同时用于系统安装记录的产品身份：即使 `installer` 用 `jsonFile` / `fileVersion` 读取版本，也可填写它定位注册表记录、实际安装目录和官方卸载器。`uninstall.name` 仅用于应用包，不能代替注册表身份规则。

`detect` 的公共字段：

| 字段 | 默认 | 说明 | 适用 method |
|---|---|---|---|
| `method` | 见条目字段表 | `none` / `registry` / `fileVersion` / `markerFile` / `jsonFile` / `appx` / `cliVersion` | 全部 |
| `name` | `registry` 未写时按 `*<name>*` 推导；`appx` 无默认 | `registry` 比 `DisplayName`，`appx` 比包名；写法见[通用匹配规则](#通用匹配规则)；`appx` 检测只接受单条字符串规则 | `registry` / `appx` 读版本；其它 installer 检测方式可用于系统身份定位 |
| `pathGlob` | `fileVersion` 缺省时取安装后的主程序；其它方式无默认 | 文件定位通配（支持 `{installDir}` / `{installRoot}`）；相对路径以安装目录为根，不依赖当前工作目录，拒绝 `..` 越界；缺少安装目录时明确报错；`file` 使用主包落位名，匹配的 `postInstallCopy` 移动规则改名后使用完整目标相对路径；无主程序可推导时报错。命中多个时逐个读取、取版本最高的那个（其余记为旧版本） | `fileVersion` / `markerFile` / `jsonFile` |
| `jsonKey` | 空 | JSON 里的版本字段名（支持点分嵌套） | `jsonFile` |
| `exe` | `mainExe` | 要运行的程序（相对安装目录或绝对路径） | `cliVersion` |
| `versionArgs` | 空或未写时 = `-v` | 取版本时传给程序的完整参数模板（如 `--version` 或 `--config "a b"`）；允许配对双引号，拒绝控制字符及未闭合双引号 | `cliVersion` |
| `versionKind` | 空 | 从原始文本里识别版本的识别器 | 全部 |
| `versionBetween` | `[]` | 用两个标记截取版本 | 全部 |
| `versionRewrite` | 空 | 归一化检测结果 | 全部 |

约束：

- `detect.method` 大小写不敏感；非空值不在上表枚举中时，报「不支持的 detect.method」并使条目解析失败
- `detect.exe` 的相对路径以安装目录为根并拒绝 `..` 越界；绝对路径保留显式指定能力。
- `detect.exe` 只对 `cliVersion` 有效；`method` 是别的时写了会报错（要求改用 `pathGlob`）
- `detect.name` 与 `detect.versionKind` 会在清单解析期编译校验，写错即条目解析失败
- 未声明 `versionKind` / `versionBetween` 时，原始文本整体像单行版本号就原样采用；否则按 `semver` → `date` → `digits` 找第一个像版本号的内容。`markerFile` 即使声明了识别规则但未命中，也执行这个兜底；其它方式不兜底。
- `cliVersion` 在一个独立隐藏进程里运行，`stdin` 立即关闭；先读 `stdout`，未识别再读 `stderr`，直接写控制台而不走重定向的输出拿不到。运行超时固定 10 秒，会连同子进程一起结束。
- 同一软件在本机装过多份时，`registry` / `fileVersion` / `markerFile` / `jsonFile` 读出全部命中版本，以最高版本作为本机版本，其余记为旧版本；`registry` 同时命中外层引导包与内层 MSI 时只采用外层引导包的 `DisplayVersion`；`appx` 只取版本最高的包。详见 `docs\install-flows.md` 的「版本检测」。
- 安装 / 更新对 `registry` / `appx` 按当前名称规则查询系统记录：完整查询成功但没有匹配时，不采用旧台账版本阻止安装；版本可读时，更新比较使用本次检测值。身份命中但版本不可读时，更新比较保留有效台账版本；台账也没有有效版本时，普通更新跳过并提示，显式 `--force` 可继续，检查模式列为「无法比较」。权限或枚举失败会明确提示并中止该软件的安装 / 更新，不按未安装处理；实际更新计为失败并返回退出码 `3`，检查模式列为「无法比较」。
- 更新检查在版本未知时先按当前 `detect` 定义重新识别并更正台账（`registry` / `appx`）。仍没有可用版本、且条目是 `source.version.from: "package"` 时：远端安装包未变化（HEAD 检测）且已下载包版本与台账记录一致，则判为「已是最新」并跳过更新（提示按安装台账判断），不会重跑安装器；远端有新包时照常取包核对。`--force` 仍强制重装。

名称规则必须限定同一产品和可比较的版本体系，不能把名称相近的软件或不同包家族一起比较：

- Windows App Runtime 的 1.x 应用包使用内部编号（如 `8000.x`），2.x 使用产品版本（如 `2.6.4.0`），两者不能直接比较。面向 2.x 及后续主系列的条目，用 `Microsoft.WindowsAppRuntime.{versionMajor}` 精确匹配目标主系列的正式版 framework 包；目标版本 `2.6.4` 展开为 `Microsoft.WindowsAppRuntime.2`。只有 1.x、其它主系列或预览通道时不算已安装该目标系列，因此会安装目标系列；同机的其它系列仍可保留。1.x 的包名包含主次版本（如 `Microsoft.WindowsAppRuntime.1.8`），若单独维护 1.x 条目，应填写对应的完整包名，不能套用仅主版本占位符的规则。命名及版本编码依据 [微软的应用包规范](https://github.com/microsoft/WindowsAppSDK/blob/main/specs/Deployment/MSIXPackageVersioning.md)。
- 微信的 `*微信*` 会同时命中「企业微信」。用 `product:微信|WeChat|Weixin` 只接受列出的完整产品名，以及可选的空白和数字版本后缀。`detect.name` 同时用于注册表版本检测、实际安装目录解析、修复扫描和注册表卸载名称规则，因而这些路径都排除企业微信。

以下是可直接放入相应条目的检测定义：

```json
{
  "detect": {"method": "appx", "name": "Microsoft.WindowsAppRuntime.{versionMajor}"}
}
```

```json
{
  "detect": {"method": "registry", "name": "product:微信|WeChat|Weixin"}
}
```

## 卸载定义（`uninstall`）

| 字段 | 默认 | 说明 |
|---|---|---|
| `commands` | `[]` | 卸载命令（结构同「命令条目」）；在删目录 / 跑官方卸载器之前执行，失败即中止，`--force` 跳过 |
| `name` | 未写时 = `detect.name` | `appx` 卸载时的包名规则，见[通用匹配规则](#通用匹配规则)；可为字符串或字符串数组，逐条展开 `{version}` / `{versionMajor}` / `{versionMinor}` 后编译，命中任意一条即纳入卸载范围；仅卸载应用包时读取 |
| `args` | 空 | 仅 `installer` 的注册表卸载：追加到官方卸载命令后的参数；应用包卸载不使用它。与根级 `uninstallArgs` 互斥 |

例如已确认官方卸载器支持 `/S` 参数时，在条目里写：

```json
{
  "uninstall": { "args": "/S" }
}
```

`uninstall` 接受 `commands`、`name` 与 `args`：删目录要回收哪些环境变量 / PATH 项由 `env` / `addToPath` 自动推导，不从这里读取。

`uninstall.name` 中的版本占位符取当前解析出的软件版本，展开结果写入解析锁和安装台账卸载快照；`re:` 规则里的版本值按正则字面量插入。声明版本占位符但没有可用版本时，条目解析报错，不会把占位符替换为空串后继续匹配。展开前后必须保持同一种匹配器，版本值不能把普通通配改成 `re:`、`product:` 或 `preset:`，发生变化时报「uninstall.name 的版本占位符不能改变匹配规则类型」。

应用包条目必须能从 `uninstall.name` 或默认的 `detect.name` 得到至少一条非空规则：空数组报「uninstall.name 至少需要一条名称规则」，空白项、非字符串项和无法编译的规则都会使条目解析失败。版本占位符区分大小写；非 `re:` 规则中的未知字母占位符会报不支持，`re:` 中拼错的 `{version...}` 模板也会报错，合法正则量词和 Unicode 属性不受影响。`product:` 规则不允许版本占位符的值包含 `|`，否则报错，避免把版本内容解释为新的产品别名。

面向 Windows App Runtime 2.x 及后续主系列的正式版条目，Framework、Main 和 DDLM 的卸载规则限定系列和通道，并明确列入正式版共享 Singleton：

```json
{
  "uninstall": {
    "name": [
      "Microsoft.WindowsAppRuntime.{versionMajor}",
      "MicrosoftCorporationII.WinAppRuntime.Main.{versionMajor}",
      "MicrosoftCorporationII.WinAppRuntime.Singleton",
      "Microsoft.WinAppRuntime.DDLM.{versionMajor}.*-x6",
      "Microsoft.WinAppRuntime.DDLM.{versionMajor}.*-x8",
      "Microsoft.WinAppRuntime.DDLM.{versionMajor}.*-a6"
    ]
  }
}
```

例如版本 `2.6.4` 展开后，Framework 和 Main 精确匹配主系列 `2`；DDLM 必须属于主系列 `2`，并以正式架构后缀 `-x6` / `-x8` / `-a6` 结束，不接受其后的预览或实验通道后缀。共享 Singleton 使用不带版本号、无通配符的完整包名，只匹配正式通道。该规则不匹配其它主系列的独立包和预览包，但会卸载跨系列共享的正式 Singleton，可能影响其它系列使用它的应用。

卸载与安装后旧包清理共用这组范围；完整卸载会处理所有匹配包，旧包清理仅移除版本低于本次检出版本的匹配包。包的系列和通道归属由名称规则确定，不能依靠内部版本号大小推断。

调整清单卸载范围后，已有台账仍优先使用原卸载快照。先用 `winst info WindowsAppRuntime --force` 定向重新解析该条目，再运行 `winst repair --offline`，使用现有解析锁扫描而不重新刷新其它软件；扫描完整查询成功并确认当前产品身份后，才尝试同步台账快照中的名称规则；已有卸载方式与当前清单不同时保留原规则。应用包还要求解析锁版本与本机检出版本的文本完全一致（包括末尾的 `.0`），否则保留原规则并提示，避免把新版本已展开的名称写入旧版本台账。应在卸载前核对确认页展示的范围。

卸载方式由 winst 根据 `type` 与主包扩展名自动判定，清单不能直接指定。内部方法名（仅出现在详情页与排错信息里）：

| 内部方法 | 触发条件 |
|---|---|
| `portable-dir` | `portable` / `file` 条目：删安装目录 + 回收系统项 |
| `registry` | `installer` 条目：实时回读注册表并运行官方卸载器 |
| `appx` | 主包是应用包，或 `detect.method` 为 `appx`：从系统应用包记录移除 |
| `clean-cache` | `download` 条目：删除已下载的软件包 |
| `record-only` | 不是 winst 安装、且软件源里没有卸载定义：只移除安装记录 |

## 包内版本派生（`source.version.package`）

安装包的文件版本信息不可信时（如 Chrome 离线安装器的 `FileVersion` 与包内真实版本不一致），声明它让 winst 用 7-Zip（`7-Zip-CLI` 引擎）读包内结构派生版本。**必须配合 `source.version.from: "package"`**。

```json
{
  "source": {
    "kind": "direct",
    "files": [{"url": "https://example.com/ChromeStandaloneSetup64.exe"}],
    "version": {
      "from": "package",
      "package": {
        "file": "*.exe",
        "inner": "updater.7z",
        "path": "*_chrome_installer.exe",
        "versionKind": "semver",
        "versionBetween": ["v", " "]
      }
    }
  }
}
```

| 字段 | 必填 | 说明 |
|---|---|---|
| `path` | 是 | 最内层压缩包里的条目路径通配（取第一个命中）；尾部 `\` / `/` 表示只匹配目录，否则只匹配文件 |
| `file` | 否 | 外层包文件通配，缺省 = 主包 |
| `inner` | 否 | 外层包里需要先取出的内层压缩包（取第一个命中） |
| `versionKind` | 否 | 从命中条目文件名识别版本的识别器 |
| `versionBetween` | 否 | 用两个标记截取版本 |

- 只接受上表五个键；写了别的会报错并列出可用键
- `versionKind` 必须是 `semver` / `date` / `digits` 之一
- 两个识别字段都不写时，按「第一个像版本号的内容」兜底

包内版本派生的 `source.version.package.path` 以 `\` 或 `/` 结尾时只匹配目录，匹配前去掉尾部分隔符，从命中目录的名称识别版本；不带尾部分隔符时只匹配文件。未命中即报错。例如微信安装包可用：

```json
{
  "version": {
    "from": "package",
    "package": {"inner": "install.7z", "path": "[0-9]*.[0-9]*.[0-9]*.[0-9]*\\", "versionKind": "semver"}
  }
}
```

此规格必须搭配 `source.version.from: "package"`；读取 `install.7z` 内版本目录（如 `4.2.0.12`），不使用外层安装器文件名中的版本。

## 源刷新与解析锁

- 刷新软件源时会对清单内**全部条目**执行一次来源解析，结果写入 sidecar（`<pkgDir>\manifests\remote\<源>.meta.json` 的 `apps` 字段），形成「解析锁」
- `install` / `download` 优先复用锁里的结果，锁未命中才在运行时重新解析
- 关键字搜索只覆盖解析锁：清单里有、但 `apps` 里还没有该 id（从未解析过）的软件搜不到；按需刷新只解析本次传入的 id，不会给未解析条目补占位记录
- 因此关键字搜索零命中时会再读一遍各源的清单正文（本地清单文件 / 远程正文缓存，这一步只读本地文件、不联网），按同样的 id / `name` / `description` 子串规则查找；命中就解析这些条目（远程源此时才联网重新取清单）并写回解析锁后重新搜索，最终仍无结果时统一提示「没有找到」——正文里没有、命中的条目解析失败，是同一句提示。正文缓存不存在（从未成功刷新过）的源无从核对；`--offline` / `--dry-run` 跳过这一步
- 每条记录带 `resolvedAt`，用于判断展示用的版本信息是否过期（`manifestTTLHours`）
- 单条解析失败不影响其它条目：记为 `ok: false` + `error`，刷新整体仍算成功
- 「下载地址 HEAD 可用性校验」在刷新阶段做：`404` / `410` 判为条目解析失败（提示清单地址失效），网络错误 / `405` 不判失败；`skipExistsCheck: true` 可关掉
- 例外：响应带 `Cf-Mitigated: challenge`（Cloudflare 人机校验页）时不判失败，按「未能确认」记一条备注。这类 CDN 对 .NET / PowerShell 客户端一律回 404（JetBrains 的中国 CDN 就是如此），文件其实存在、下载引擎也下得动，按 404 报错只会冤枉清单；代价是这类站点上「真的写错了地址」同样只能等到安装时才暴露
- 同一进程内对「方法 + URL」的响应做 TTL 10 分钟缓存（GitHub 网页通道、`listing` / `page` 页面、`json` / `xml` 接口、校验文件、HEAD 探测），进程退出即失效

## 依赖与分组

- `dependencies` 是「安装这个之前需要装什么」，winst 只处理未装 / 可更新的部分，与本体一起确认。本体使用用户已选来源的依赖；每个依赖使用最高可用版本的来源并继续解析该来源的依赖，不合并其它来源的声明
- 依赖**不会**自动写进安装清单：清单只记录用户显式选择，安装时再补齐依赖
- 卸载时列出「哪些已安装软件依赖它」，仅提示、不拦截
- `bundle pack` 会收集依赖闭包
- `group` 只影响展示顺序与分组标题，不参与版本比较和安装流程

## winst 内置使用的条目 id

只有三个 id 被 winst 自己识别（写死在代码里），它们必须在软件源里存在、且保持这个 id：

| id | 用途 | 何时自动安装 |
|---|---|---|
| `winst` | winst 自身（`type: portable`，主程序 `winst.cmd`） | 安装任意其它软件前（`Confirm-WinstSelf`）；已装则检查并应用更新 |
| `7-Zip-CLI` | 解压引擎，专用目录只落地 `7z.exe` + `7z.dll`；首次引导解压失败时借助系统 7-Zip 解包，缺失则以 `/S` 静默安装；更新时使用旧引擎解包 | 每次解压前（`Confirm-WinstExtractEngine`） |
| `FluxDown-CLI` | 下载引擎（`fluxdown.exe`） | 每次下载前（`Confirm-WinstDownloadEngine`） |

这些 id 的引导流程由 winst 内置识别，其它条目按普通软件处理。引擎使用独立目录；离线时缺失引擎不会自动安装。引导的执行顺序、包内文件选择、系统 7-Zip 安装与保留行为见 [下载与解压引擎](install-flows.md#下载与解压引擎)；自身安装见 [winst 自身的安装与更新](install-flows.md#winst-自身的安装与更新)。

## 兼容字段对照

分散字段单独使用时继续支持，推荐示例统一使用右列。新旧写法均须遵守字段类型、适用范围与互斥约束；摘要来源只选一种，不按覆盖优先级取舍。同一组的新对象与左列任一字段同时出现会报错，即使两边的值相同也不选取优先级。对象结构不会自动让不适用于当前来源的字段生效。

| 分散字段 | 推荐位置 |
|---|---|
| 条目 `version` | `source.version.value`，仅 direct |
| `source.versionFrom` | `source.version.from` |
| `source.versionUrl` | `source.version.url`，用于 direct / page 的独立 header / JSON 版本地址 |
| direct 的 `source.pageUrl`，且 `versionFrom: page` | `source.version.url`；page 来源自己的 `source.pageUrl` 保持不变 |
| `source.versionHeader` | `source.version.header` |
| `source.versionKey` / `source.versionXPath` | `source.version.key` / `source.version.xpath` |
| `source.versionKind` / `source.versionBetween` | `source.version.kind` / `source.version.between` |
| `source.versionFilter` / `source.sort` | `source.version.filter` / `source.version.sort` |
| `source.versionRewrite` / `source.packageVersion` | `source.version.rewrite` / `source.version.package` |
| `files[].hash` / `hashHeader` / `hashKey` / `hashXPath` | `files[].checksum.value` / `header` / `key` / `xpath` |
| `files[].hashFile` / `hashFileKey` / `hashFileMatch` | `files[].checksum.file` / `fileKey` / `fileMatch` |
| `files[].hashFrom` | `files[].checksum.format` |
| `source.hashClick` | `source.files[0].checksum.click`，两者不能同时声明 |
| 根级 `uninstallArgs` | `uninstall.args`，两者不能同时声明 |

`source.follow.versionKey` / `versionFilter` / `sort`、`detect.versionKind` / `versionBetween` / `versionRewrite`、文件级 `versionKind` / `versionFilter` / `versionRewrite` 及包内派生对象里的 `versionKind` / `versionBetween` 不在这次归组中，字段名不变。报错中的分散字段名可能来自内部读取步骤，可按本表定位对应的作者字段。

## 常见写错与报错

| 现象 | 原因 |
|---|---|
| `source.version.from 不适用于…` | 该 kind 不支持这个取值，见「下载来源」表 |
| `versionFrom: file 但没有写 versionKind / versionBetween` | github 的 `file` 必须给出识别方式 |
| `source.versionKind 不适用于当前来源和版本读取方式` | github 默认用 tag 当版本，要取文件名里的版本必须显式声明 |
| `source.link 与 source.click 只能写一个` | 两者互斥 |
| `source.hashClick 要和 source.click 或 source.thenClick 搭配` | `checksum.click` 需要无头取址会话；不能单独写在只有 `link` / `thenLink` 的条目上 |
| `source.hashClick 只配合 files[0].hashFrom: "page"` | 声明了 `checksum.click` 但主包没有 `checksum.format: "page"` |
| `source.link 至少要写一个条件` | `source.link` 是空规则；`source.thenLink.link` 为空时也有对应的明确报错 |
| `urlKey（接口字段）只能用在 JSON / XML 接口源` | `urlKey` 只用于 json / xml 源 |
| `urlXPath 只用于 XML 源，且不能与 url / urlKey / file 同时配置` | `urlXPath` 是 xml 专属，且与同一文件的其它定位字段互斥 |
| XML 的字段路径或 XPath 没有匹配或匹配多个节点 | 父记录与文件记录筛选结果必须唯一；取值字段也必须唯一，不自动挑选记录 |
| `同一个文件不能同时填写 url 和 file` | `url` / `urlKey` / `file` 的互斥组合写错；json 主包允许 `urlKey` + `file` |
| `source.packageVersion 不适用于当前来源和版本读取方式` | 派生规格必须与 package 版本来源搭配 |
| `source.version 不能与 source.versionFrom 同时填写` | 同一组的集中写法与分散写法混用；改为仅保留 `source.version` |
| `必须且只能声明一种摘要来源` | 同一个 checksum 同时填写多个选择字段，或 format: page 又填写了其它来源 |
| `不支持的 portableMode` | 只接受 clean / overwrite，不把拼写错误当默认清理模式 |
| `postInstallCopy[0].to 不能为空` | 复制规则缺必填目标路径；命令缺 exe 同样会明确报字段错误 |
| `detect.exe 只对 cliVersion 有效` | 别的检测方式要用 `pathGlob` |
| `软件源条目 id 不合法` | id 不是单层目录名（含 `/` `\` `..` 或超长） |
| `installArgs 含有控制字符或未闭合的双引号` | 参数模板必须引号配对 |
| `软件源里的解压路径…不能包含上级目录（..）` | `extractFiles` / `stripTopDir` / `installerExe` / `postInstallCopy` 都不允许越界 |
