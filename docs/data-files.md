# 数据文件

## 位置总览

```
%USERPROFILE%\.winst\                    数据目录，可用 WINST_HOME 覆盖
├── winst.lock                           数据目录锁（记录占用者 PID、启动时间和运行路径）
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
├── winst\                               winst 自身（winst.ps1 + winst.cmd + LICENSE + Modules\）
└── <id>\                                各软件安装目录
```

- `pkgDir` 可指向 U 盘或 NAS，安装包、源列表和清单缓存随之一同共享。
  网络共享**只支持 UNC 路径**（`\\服务器\共享名\目录`），不支持映射盘符（`Z:\...`）：映射只在当前登录会话可见，winst 以管理员身份运行时往往访问不到。
  UNC 拒绝设备命名空间、空路径段、非法字符、`.` / `..` 及共享名或子路径段的尾点、尾空格；规范化失败会报错。共享名可带 `$`。配置、环境变量与命令行中的 UNC 路径使用相同校验。
  共享需要认证时，在「设置 → 安装包位置」里先输入 UNC 路径，再按提示单独输入账号与密码（密码不回显）。账号处回车跳过认证；填写账号后密码必填，空密码会返回账号输入。winst 先验证账号和密码，再让 Windows 保存登录信息。确认可以打开共享文件夹后，才保存它的位置。`config.json` 只记录路径。路径里不要写账号密码。
  系统错误 `1219` 表示对应服务器已有其它凭据的 SMB 会话，需手动处理该服务器的连接；winst 不清空其它共享连接。验证后临时 `IPC$` 会话清理失败时显示残留警告，即使凭据随后保存成功也保留该警告。
- `installRoot` 只允许本地路径，拒绝 UNC 和网络映射盘；配置、环境变量和命令行覆盖都遵循此限制，只有 `pkgDir` 可以使用 UNC 共享。更改 `installRoot` 只对此后的安装生效：已装软件留在旧位置继续可用，改完会列出旧位置里已有的软件目录。安装记录跟着安装位置存放，新位置暂时是空的。
- 新位置没有台账时，`winst repair` 会扫描安装目录、注册表和 Appx 记录来重建，进入「已装软件」也会执行修复扫描。
- winst 写出的 JSON、`.list` 和生成的文本文件使用 UTF-8 无 BOM。`Write-FileAtomic` 检查目标路径链后先写临时文件，再进行原子替换；替换失败保留原文件并明确失败，不退化为直接覆盖。写入或替换失败同样会清理临时文件；共享目录「可写不可删」或临时文件被其它进程占用导致删不掉时，`--verbose` 会给出路径（清理失败不影响写入结果，也不掩盖原始错误）。
- 入口同时持有数据目录的 `winst.lock` 与 Temp 下的 `.winst-stage.lock`，分别防止数据并发写入和固定暂存目录冲突。暂存锁位于 `.winst-stage` 旁，两个句柄都在业务及暂存清理结束后释放。锁文件保留供下一次启动复用。占用状态由句柄决定，进程被强制终止时由系统释放句柄。只读的版本/帮助调用不抢锁。

## config.json

| 键 | 类型 | 默认值 | 说明 |
|---|---|---|---|
| `installRoot` | string | `%USERPROFILE%\winst` | 本地软件安装根目录与台账位置，拒绝 UNC 和网络映射盘；环境变量/PATH 的作用域由实际安装目录是否位于 `%USERPROFILE%` 下决定 |
| `pkgDir` | string | `<数据目录>\apps` | 安装包与清单数据位置 |
| `pruneOldPackages` | bool | `true` | 新版本下载成功后删除同 id 目录中不在本次保留列表里的旧文件 |
| `manifestTTLHours` | int | `24` | 软件源及逐条版本信息的缓存有效期（小时）；不大于 0 时逐条信息视为总过期 |
| `proxy` | string | 空 | 代理地址 |
| `fluxdownApi` | string | `""` | FluxDown 本机管理服务的 HTTP(S) 根地址，可使用回环 IP 或 localhost。留空时，可以沿用 FluxDown 里设置的地址。如果环境变量和 FluxDown 里都没设置地址，就使用 `http://127.0.0.1:17800`。 |
| `fluxdownToken` | string | 空 | Windows 当前用户的 DPAPI 密文。通过设置菜单或 `winst config set fluxdownToken` 隐藏输入，查询时仅显示「已设置」或「未设置」 |
| `proxyMode` | string | `auto` | `auto` 系统默认连接失败再试配置的代理；`always` 使用配置的代理；`off` 只用系统默认连接（可能使用系统代理/PAC）；`download-direct` 下载先用系统默认连接、失败再用配置的代理，其它请求用配置的代理。当次显式传入非空 `--proxy` 时覆盖代理地址，且 `off` 按 `always` 处理。未配置代理地址时均使用系统默认连接 |
| `updateFilesOnly` | bool | `true` | 更新已登记软件时只替换文件，不改环境变量和 PATH；已存在的快捷方式仍会校验并修正指向错误 |

- 路径支持 `%VAR%`，写入时保留原文，读取时展开；相对路径以数据目录为基准归一化。
- 布尔项接受 `开` / `关`、`on` / `off`、`true` / `false`、`yes` / `no`、`y` / `n`、`1` / `0`；无法识别的配置值不会被当作明确的 false。
- 文件缺失、损坏或缺键时按默认值运行：缺键只补该键；整份无法解析时先备份为 `config.json.bak`（同一份坏文件只留一份）并提示一次，再按默认值运行，不会静默丢弃用户原来的设置。只有表中键参与默认配置读取，未知键不会从手工配置文件并入当前上下文；保存配置时按固定键集写出。
- GitHub 通过网页通道访问，不需要令牌。
- FluxDown 地址和 Token 分别按环境变量（`FLUXDOWN_URL`、`FLUXDOWN_TOKEN`）、winst 显式配置、`%APPDATA%\zerx\fluxdown\config\cli.toml`、默认值的顺序取用。清除 winst 的显式值后按此顺序重新取值。需要从 `cli.toml` 取值时，字段格式错误会使服务探测失败，诊断给出行号和字段名，Token 值始终隐藏。

**路径解析优先级**

```
pkgDir      : --pkg-dir > WINST_PKG_DIR > 脚本同目录已存在的 apps\ > 有效 config.json > <数据目录>\apps
installRoot : --install-root > WINST_INSTALL_ROOT > 有效 config.json > %USERPROFILE%\winst
```

首次设置和后续修改都会先用待保存的配置解析生效路径，写入成功后菜单才显示新的路径和来源。手动恢复默认文件夹时，请删除对应的设置项。如果把 `pkgDir` 或 `installRoot` 写成 `""`，这次运行会对所有设置使用默认值。脚本同目录存在 `apps\` 即优先作为包目录，这正是离线套装的零配置入口；可用参数或环境变量显式覆盖。

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
      "appliedEnv": [ { "name": "JAVA_HOME", "scope": "Machine", "existed": true, "previous": "D:\\LegacyJdk" } ],
      "appliedPath": [ { "path": "D:\\Apps\\jdk21\\bin", "scope": "Machine" } ],
      "appliedShortcuts": [ "C:\\Users\\me\\Desktop\\Eclipse Temurin JDK 21.lnk" ],
      "appliedFiles": [ "colors\\Alabaster.icls" ],
      "appliedFileRules": {},
      "oldVersions": [ { "version": "21.0.4", "detail": "系统安装记录: Eclipse Temurin JDK with Hotspot 21.0.4+7 (x64)", "recordKey": "Registry64::HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{旧版 JDK 的产品代码}" } ],
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
- JSON 无法解析时，先备份为 `state.json.bak-<日期和时间>-<8个随机字符>`，再在内存中重建空台账。备份失败会返回错误并停止写入，避免覆盖唯一副本；成功备份后的重建由后续保存落盘。
- `installedAt` 是首次安装时间，`updatedAt` 是最近一次通过条目级接口写入该记录的时间。修复扫描的整份合并保存不经过该接口，不会统一重写这两个时间戳。
- `appliedEnv` 的 `name` / `scope` 标识实际写入项；`existed` 记录接管前变量是否存在，`previous` 保存当时原始值。再次完整更新保留同名称与作用域的首次恢复信息。旧记录缺少恢复字段时不猜测原值，卸载保留该变量并提示。`appliedPath` 只登记实际写入项；`appliedShortcuts` 还可登记经台账与摘要确认的共享链接。卸载时仍有其它软件使用的环境变量 / PATH，其清理登记移交给剩余软件；环境变量的已有共享登记沿用最早已知登记的恢复值。移交通过条目级写入保存，失败时保留原软件记录。repair 新扫描的条目不根据清单推导这些登记。
- `appliedFileVersions` 保存实际落位附件的元数据快照，包括版本、ETag、修改时间、大小、校验摘要、`compare` 和落位所用包的实测 `sha256`。附件落位成功后提交快照，失败时保留此前的记录。
- `appliedFiles` 记录附加文件落位路径；`appliedFileRules` 是内部文件名到落位规则 JSON 文本的字典，规则包含 `dest` / `extract` / `stripTopDir`。只更新附件时，落位规则一致、目标存在、未重新下载且缓存摘要匹配已安装快照的附件可以跳过。旧记录缺少落位规则或摘要时重新落位一次。该字段不属于第三方清单。`managed` 为 `winst` 或 `external`，外部登记的实际写入项为空；卸载程序仍可按当前清单定位，环境变量、PATH、快捷方式以实际登记为准。
- `uninstall` 保存安装时的卸载操作；源条目删除或修改后，已登记软件仍可使用快照。`nameRule` 可以是字符串或字符串数组。
- 卸载及共享系统项判断只读取 `manifestOrigin` 对应来源的解析锁；来源未知、已移除或该来源没有可用计划时只使用台账快照，不采用其它同 id 来源的定义。
- `appliedShortcutHashes` 保存快捷方式文件 SHA256，路径对应 `appliedShortcuts`。实际创建或修正时记录摘要；复用其它条目的链接时，仅在台账登记与当前摘要一致时保存相同路径及摘要作为共享引用。已有且无需改写的用户链接不认领；卸载按 `appliedShortcuts` 登记的路径直接删除链接，不检查内容摘要或是否被修改；其它已装条目仍引用的链接保留并提示，最后一个引用者卸载时删除。该字段由 winst 写入，不是清单字段。
- `oldVersions` 记录与当前版本并存的同产品低版本，结构为 `{ version; detail; recordKey }`；`recordKey` 使用 `Registry32::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\<键名>` 或 `Registry64::...` 标识视图，用户级记录的根为 `HKEY_CURRENT_USER`。回读与删除使用同一视图；兼容旧提供程序路径，其中 `WOW6432Node` 指向 32 位视图，其余路径在 64 位系统指向 64 位视图。卸载入口选择与各检测方式的行为见 [安装流程](install-flows.md#版本检测)。有效检测命中时更新并清退消失版本，检测未完成或版本未知时保留已有记录。
- `installed` 的 id 使用 Ordinal 比较；写入拒绝仅大小写不同的冲突身份，避免共享 Windows 目录或产生不可解析的 JSON 属性。
- `download` 类型不写安装台账。

### 条目级写入与读缓存

安装、更新、引擎和 winst 自身记录、外部登记都通过 `Save-WinstInstalledAppEntry`：重读最新台账，只覆盖目标 id，沿用已有 `installedAt`，写入当前 `updatedAt`，最后整份原子落盘。这样可避免安装流程开始时的旧快照覆盖嵌套引擎或自更新流程刚写入的记录。卸载时先读最新的安装记录，只删掉当前软件。修复时把扫描结果合并到安装记录中再保存。

`Read-WinstState` 按路径和文件戳（最后写入时间、长度）缓存解析并归一化后的台账：

- 命中文件戳时，`Copy-WinstState` 返回新的外层字典。默认逐条复制，条目内数组及 `uninstall` 等嵌套对象按引用共享。指定 `-ForEntryReplacement` 时整个条目按引用共享。
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
        "sourceVersion": "",   // 未独立解析出文件版本时为空
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

- `hashes` 保存各文件从本地安装包计算得到的 sha256；`manifestHashes` 保存本地安装包按软件源声明算法计算得到的摘要（非 SHA256 时单独记录）。这两项是本地实测值，远端期望值另存于 `fileMeta.expectedHash`；新下载的包必须实算并比对，通过后同时写入索引。
- `version` 是已缓存主包的版本。下载并校验新主包时，按清单登记本次远端版本，或从主包、指定附件读取一次软件版本。登记值已应用 `source.version.rewrite`。以后复用主包直接使用此值，刷新软件源、改变取版规则或单独更新附件均保留它。
- 旧条目缺少 `version` 时，安装、下载或制作套件需要版本且清单支持包内取版，winst 会补读并写回。只能从远端取版的旧包显示「缓存版本未知」，下次下载主包时登记。手工替换文件时请同步更新或清除该文件的登记；替换主包还需更新或清空 `version`。
- 条目级 `downloadedAt` 记录主包下载时间。主包缺少文件级下载时间时沿用已有条目时间。每个附件在自己的 `fileMeta` 中记录下载时间。
- 新任务在 `<pkgDir>\<id>\winst-download\<任务标识>\` 中下载。每个软件共用一份 `winst-download\.tasks\<id>.json`，其中 `files` 按文件名分别保存主包和附件的任务。桌面服务接单前记录下载目录、来源、版本和预期摘要，接单后补写任务 ID；创建响应丢失时按工作目录找回。独立 CLI 和 HTTP 引导下载在文件校验通过后写入完成记录。下载链接和请求凭据以指纹比较。
- 恢复按文件名单独保存的服务记录时，winst 先合并记录，再连接原服务核对任务。若同名记录指向同一工作目录，且服务、计算机、磁力标志、版本和摘要一致，从单文件记录补齐汇总条目缺少的任务 ID、请求指纹和地址指纹。非空标识或指纹冲突时保留两份记录并报错。若单文件记录没有 `workId` 而汇总条目已指定独占目录，使用汇总条目。合并结果写入成功后清理单文件记录。服务任务的 `workId` 缺失、为 `null` 或空字符串时沿用原路径。普通下载位于 `winst-download\`，磁力下载位于 `winst-download\.local\<文件名>\partial\`。来源名或版本字段中的 `null` 和空字符串视为相同值，来源或版本有变化时重新下载。记录缺少来源名或包版本字段时，通过身份核对后补记，并沿用原任务 ID。
- 校验成功后记录文件的实际名称和 SHA-256，再将文件移动到 `<pkgDir>\<id>\<文件名>` 并更新 `winst.json`。登记完成后清理该文件的任务记录和工作目录。移动失败可重试移动；移动后登记失败则重新核对正式文件并补登记。FluxDown 桌面保留完成历史。
- 重新下载时，已停止的旧任务文件会保留到该软件的全部文件校验、移动和登记成功，再统一清理。打开缓存详情时，会清理未绑定任务的空工作目录，即使首次下载还没有登记文件。已有正式缓存时，也会清除与已登记文件内容相同的闲置副本。没有正式副本、也无法核实写入状态时，保留非空工作目录。确认下载进程已停止且可以丢弃该软件的全部缓存后，可执行 `winst clean <id>`。汇总记录和带有原服务地址、计算机名的旧记录会阻止整包清理，包括文件名恰好带临时后缀的完整旧记录。半写的原子临时文件、仅含汇总数据的临时副本和 `replaced` 子目录可随包清除。

- `fileMeta` 记录下载或按当前源摘要验证的来源名（`manifestOrigin`）、实际 URL、文件自身版本（`sourceVersion`）、HTTP 校验器（`etag` / `lastModified`）、大小、下载与检查时间，以及 `expectedHash`（远端期望摘要）、`expectedAlgorithm`（摘要算法）和校验文件声明。读取已有文件记录时使用登记的来源名。`manifestOrigin` 缺失或为空白时按官方源 `dsx42/winst-manifest` 处理。文件在 `fileMeta` 中没有记录时，来源仍未知。`sourceVersion` 只在这个文件有自己的版本时才有值：从包内取版的主包写空；配套文件仅当声明 `files[].versionListUrl` 并独立解析出版本时记录。它同时用于新鲜度判断、声明变更检测和离线校验；切换 `hash` / `hashFile` 时来源字段必须成组更新。
- 文件名、下载地址、该文件自身版本、`hashFile` 地址与 `hashFrom` 规则形成声明指纹，匹配时在线与离线安装都可复用已保存的远端期望摘要。已登记的包文件仍存在时，按算法复用索引中的实测摘要。缺少所需算法的摘要时计算并随索引写回保存。在线发现不一致则重取，离线保留文件并报错；缺少匹配的期望摘要时需联网补取，离线明确报错。未声明摘要的包按新鲜度规则判断。配套文件的指纹只使用文件自身版本。`compare` 含 `checksum` 时主动重读校验文件。需要重新下载时，统一重新请求校验文件并用新取得的摘要校验新包。
- 索引在进程内按文件戳缓存，命中后仍检查目录是否存在。`Save-WinstCacheIndex -Update` 在持有包目录下的 `winst.json.lock` 时重新读取索引，再执行修改块；修改块只改本次涉及的条目，不回写旧快照。字段与值相同时不重写索引，数据变化时经 `Write-FileAtomic` 原子写入并失效 JSON 缓存。安装、清理、修复和套件制作共用此入口。
- 整份索引缺失或损坏时按目录中的文件名重建，版本、摘要和下载时间留空；根必须是对象，数组和标量按损坏处理。损坏文件先安全备份为 `winst.json.bak`，原文件和备份路径均不得经过重解析点。已有备份与原文件摘要一致时直接复用，重新复制后须核对备份摘要。备份失败时可以展示内存重建结果，但禁止写回索引。单条记录无法归一化时只重建该条且不立即整份回写，避免误伤原文中的其它记录。
- 索引中目录已不存在的条目会从内存结果剔除，`Changed` 为真时由修复或后续写入落盘。`winst repair` 会校对并保存必要的索引修复，但不删除安装包。
- `<pkgDir>\.winst-locks\<id>` 按软件包协调规划、发布、记账、安装读取、套件复制和清理。本地与 UNC 使用相同规则。`winst.json.lock` 协调索引读改写。同一个锁等待最多 10 秒，超时或权限错误会报告，进程结束后系统释放句柄，锁文件保留。软件源刷新有各自的流程。

## 清单文件（.list）

安装清单是 UTF-8 行式文本。清单目录优先使用脚本同目录下已有的 `lists\`，否则使用 `<数据目录>\lists\`；默认文件名为 `setup.list`。

```text
# 重装系统后要装的软件
jdk21
idea
vscode==1.96.0
```

- 空行忽略，`#` 开头为注释；保存时注释集中写在文件开头，随后按条目顺序写回，不能保留原始行位置。
- 每行是 `id` 或 `id==版本`；行尾没有单独的注释语法，示例中的注释必须独立成行。同一 id 只保留第一次出现，比较区分大小写；非法 id 行记为坏行，保存时会丢弃，调用方负责提示。
- 编辑清单时保存用户选择的条目。制作套件时，目标清单还包含引擎、winst 和传递依赖。
- `id==版本` 用于声明期望版本；联网时与明确的源版本比较，离线 `bundle install` 与实际缓存包版本比较。版本不一致或待确认时会提示，菜单可选择继续或跳过，CLI 继续执行可用计划。
- 通过清单管理功能输入的显式路径也必须位于当前清单目录下，并统一使用 `.list` 后缀，防止任意路径写入。

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

仅文件缺失视为空列表；空正文、非法 JSON、错误结构或无法读取时明确报错，停止源列表写入并保留原文件。空源列表可写为 `[]` 或含空 `sources` 数组的对象。

内置源 `dsx42/winst-manifest` 始终由 `Ensure-OfficialManifest` 维护：缺失时补到首位，地址偏离时恢复，不在首位时挪回首位。内置源仓库只分发 `manifest.json`，软件包来自条目声明的地址，不依赖该仓库的 release。

## manifests/remote/*.meta.json（sidecar 与解析锁）

```jsonc
{
  "url": "https://raw.githubusercontent.com/dsx42/winst-manifest/main/manifest.json",
  "version": "2026.10.20",
  "fetchedAt": "2026-10-20T16:49:00",
  "resolvedAt": "2026-10-20T08:49:12.0000000Z",
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
  "resolvedAt": "2026-10-20T08:49:12.0000000Z",
  "versionFromPackage": false,
  "sourceVersion": "jdk-21.0.5+11",
  "sourceVersionRewrite": [ { "pattern": "^jdk-", "replace": "" } ],
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
  "detect": { "method": "fileVersion", "pathGlob": "{installDir}\\bin\\java.exe" },
  "uninstall": { "method": "portable-dir", "removeEnv": [], "removePaths": [] }
}
```

- sidecar 的所有字段与磁盘记录相同时不写盘，保留文件内容、修改时间及汇总缓存；对象键顺序或 JSON 排版差异不触发写入。真实刷新产生的新时间戳属于记录变化，仍需保存，以维持共享缓存的有效期判断。
- `resolvedAt` 使用带时区的 UTC 格式；读取兼容没有时区的本地时间文本。
- 顶层 `fetchedAt` 是本次取得或复用清单的时间，每次成功刷新都会改写；顶层 `resolvedAt` 是本次 sidecar 写入时间。每条 `resolvedAt` 用于 `manifestTTLHours` 的按需刷新判断，保留上次成功结果时也会更新为本次尝试时间。
- `version` 已应用版本改写，`sourceVersion` 保留上游值，`sourceVersionRewrite` 供后续包内派生版本使用。`remoteFresh` 记录包内取版条目的远端文件与缓存包比对结果，取 `changed` / `unchanged` / `unknown`。结论为 `unchanged` 时，`remoteFreshHash` 保存当时缓存主包的 SHA256，供后续复用时核对。主包重新下载、读出版本并写入缓存索引后，winst 更新相应来源解析锁的远端比较结论和主包 SHA256。列表和更新检查按当前索引读取已确认的版本。单独下载附件时沿用主包已经登记的版本。

`versionFromCache: true` 表示版本取自缓存包或缓存索引，包括下载后从包内确认的读数；它与同一来源计划的 `remoteFresh` 一起供展示和更新判定使用，不参与跨来源远端最高版本或联网安装清单的固定版本比较。离线套件安装按所选来源的缓存包比较固定版本。缓存版本取自 `winst.json`。使用 `unchanged` 判断远端版本时，索引主包摘要必须与 `remoteFreshHash` 一致。
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
└── lists\                    本次生成的安装清单，以前打包的清单也会保留
```

- 收包顺序与写入目标套件的 `.list` 一致。前三项依次是 `7-Zip-CLI`、`FluxDown-CLI`、`winst`。其余软件先列传递依赖，再列依赖它的软件；每个 id 只出现一次，保留清单里的固定版本与无关软件的相对顺序。
- 制作完整套件会刷新所需软件的来源，核对所有主包和附件，下载缺失、已变化或无法确认远端未变的文件。下载后重读缓存索引并核对计划需要的文件及声明摘要，全部通过后才复制。`--skip-missing` 按本地缓存制作并报告缺项，目标清单仍列出所需条目。打包时按实际选中的主包确定版本；同一软件目录中另一个包的登记版本不能作为该主包的版本，无法确认时在套件索引中留空。`--dry-run` 只预览本地缓存。
- `apps\manifests\` 复制源列表、远程缓存和 sidecar；脚本同目录的本地清单另外复制。索引保留目标已有的无关条目，并从来源缓存复制实际入套件的文件摘要与 `fileMeta`。打包时，`bundleSource` 记录选定的来源。更新缓存索引时，已有的 `bundleSource` 随主包 `fileMeta.manifestOrigin` 的有效值同步。从新来源下载主包，或用新来源声明的摘要确认现有主包，都能完成换源。仅更新附件且主包来源未变时，套件继续使用原主包来源。离线批量安装时本体和传递依赖各用自己的登记来源。旧套件可沿用索引首个包文件的 `fileMeta.manifestOrigin`。
- 同版本按文件摘要比较，双方均有登记摘要时直接比较索引。目标文件存在且摘要相同才跳过，十六进制字母大小写不影响比较。版本不同、缺少版本记录或索引含有用不到的旧文件时，先安全清理该 id 的旧目录再复制。只处理本次涉及的 id 目录。
- `winst.cmd` 由打包流程生成，模块和本地清单来自当前运行副本，而不是重新下载 release。目标机通过启动器或直接运行脚本时，脚本同目录 `apps\` 自动成为包目录，`lists\` 自动成为清单目录；菜单读取、编辑和新建均使用随包清单目录，配置与安装台账仍使用各自的数据目录。在目标机运行 `winst.cmd bundle install <清单名> --offline` 可按套件来源与本地包版本安装。主包版本与解析锁不同时，winst 可用同来源清单按缓存版本重新展开安装、检测和卸载步骤。只有解析锁的旧套件，如果能确认执行步骤与默认的单文件落位或直接运行主包一致，也能安装。无法匹配计划时会报告缓存版本和解析锁版本。使用 `setup.list` 时可省略清单名。

套件重复制作时整棵替换 `Modules`，避免残留旧模块或形成 `Modules\Modules`。任何待复制安装包失败都会使打包命令返回失败；已经复制的内容会保留，可修复原因后重试。
