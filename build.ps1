#Requires -Version 5.1
<#
    build.ps1  (仓库根)

    把 Modules\ 下的模块打成「单一模块」形态，产出 release 压缩包。

    用法
    ----
        build.cmd                             双击 / cmd 里直接跑
        build.cmd -NoPause                    构建后直接返回
        $env:CI='1'; cmd /c build.cmd         非交互环境（不等待）

    版本号
    ------
    唯一来源是 Modules\Winst.Core\Public\WinstConstants.ps1 的 Get-WinstProductVersion。
    发版前由开发者自己改那个文件；构建只读取它、打印它来自哪个文件，
    不写回任何东西。tag 必须与它一致（v<版本>）。

    为什么打成一个模块
    ------------------
    Windows PowerShell 5.1 每次 Import-Module 都要建一次会话状态、读一次清单，
    再逐个点源函数文件。开发树是 13 个模块、近 700 个 .ps1，冷启动约 10 秒。
    合并成一个 .psm1 后 release 只需一次 Import-Module，冷启动降到 4 秒量级。

    模块来源与顺序
    --------------
    不维护任何清单：Modules\ 下每个「目录名与清单同名」的子目录就是一个模块
    （Modules\Winst.Foo\Winst.Foo.psd1），按目录名排序处理。新增 / 删除 / 重命名
    模块只需要动磁盘上的目录，本脚本和 winst.ps1 都不用改。

    顺序不影响正确性：函数文件只定义函数，加载期没有互相调用。合并时若出现同名
    函数则直接构建失败——那才是唯一会让顺序变得要紧的情况。

    合并规则
    --------
        1. 模块按目录名排序
        2. 每个模块先 Private\ 再 Public\，各自按路径排序（与 .psm1 加载器一致）
        3. 函数之间没有重名才允许合并（重名会静默覆盖，直接构建失败）
        4. 导出名单在构建期算好，release 里不再做 AST 扫描
        5. 每个文件开头的 #Requires 去掉，只在文件顶部保留一条

    产物
    ----
        dist\winst\             可直接运行的发布树（这就是 zip 的内容，未压缩）
        dist\winst.zip          从 dist\winst\ 压缩得到
        dist\winst.zip.sha512   sha512sums 格式：<摘要>  winst.zip

    发布树内容
    ----------
        winst.ps1  winst.cmd  LICENSE  Modules\Winst\

    LICENSE 是 GPLv3 原文，随分发必须保留；README.md 面向仓库访客，不进 release。

    dist\winst\ 保留在磁盘上：测产物时直接跑 dist\winst\winst.cmd，
    不必先解压。它比 zip 多一个仓库的 manifest.json（本地测试用，见下），
    除此之外两者内容一致。

    测试用清单
    ----------
    打包之前把仓库根目录的 manifest.json 复制到构建树：产物目录因此可以
    直接当「脚本同目录」来测本地软件源条目，不必额外拷文件。
    打压缩包时按条目名跳过它，**不进 winst.zip**，release 资产保持干净。

    构建校验（任一失败即中止；全部通过后才把产物放进 dist\）
    ----------------------------------------------------
        - Modules\ 下每个子目录都必须能作为模块识别（同名 .psd1 / .psm1 / Public\）
        - 源文件必须 UTF-8 with BOM + CRLF；缺 BOM 或用 LF 直接报错并列出文件
          （5.1 按系统 ANSI 读无 BOM 文件，中文会静默乱码；构建不做自动修正）
        - 合并结果能通过 5.1 语法解析
        - 构建树在临时目录里能直接 `winst.ps1 -v` 起来，且报出的版本等于产品版本
        - 压缩包不含 manifest.json / docs\ / build.* / install.ps1，且没有单一顶层目录
        - 全部通过才把产物放进 dist\（dist\ 在构建开始时已清空）
#>

[CmdletBinding()]
param(
    # 结尾不等待回车。CI 里也可以设 CI=1 达到同样效果。
    [switch]$NoPause
)

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repo = $PSScriptRoot
if (-not $repo) {
    throw 'build.ps1 必须用文件方式运行：powershell -NoProfile -ExecutionPolicy Bypass -File .\build.ps1'
}

$bundleName = 'Winst'
$modulesDir = Join-Path $repo 'Modules'
$constantsPath = Join-Path $modulesDir 'Winst.Core\Public\WinstConstants.ps1'
$interactive = (-not $NoPause) -and ($env:CI -ne '1')

# 产物目录固定为 <仓库>\dist：本脚本只负责打包，不做通用构建。
$dist = Join-Path $repo 'dist'
$releaseDir = Join-Path $dist 'winst'
$zipPath = Join-Path $dist 'winst.zip'
$sidecar = Join-Path $dist 'winst.zip.sha512'
$zipTemp = $zipPath + '.tmp'

Write-Host ''
Write-Host '  winst 构建' -ForegroundColor Cyan
Write-Host '  ----------------------------------------' -ForegroundColor DarkGray

if (-not (Test-Path -LiteralPath $modulesDir -PathType Container)) {
    Write-Host ('  [x] 当前目录不是 winst 仓库：缺少 Modules\（{0}）' -f $repo) -ForegroundColor Red
    exit 1
}

# ------------------------------------------------------------------ 清空产物
# 每次构建都从空 dist\ 开始：留在里面的旧文件不属于这次构建，
# 混在一起会让人误以为它们也是本次产物。
if (Test-Path -LiteralPath $dist) {
    try {
        Remove-Item -LiteralPath $dist -Recurse -Force -ErrorAction Stop
        Write-Host ('  清空产物   : 已删除 {0}' -f $dist) -ForegroundColor Gray
    } catch {
        Write-Host ('  [x] 无法删除 {0}：{1}' -f $dist, $_.Exception.Message) -ForegroundColor Red
        Write-Host '      产物可能正被占用（正在运行的 winst、资源管理器或编辑器），关掉后重试。' -ForegroundColor DarkYellow
        exit 1
    }
}

# ------------------------------------------------------------------ 工具函数

function Get-ProductVersion {
    <#
    .SYNOPSIS
        从 WinstConstants.ps1 读产品版本（唯一来源）。
    #>
    if (-not (Test-Path -LiteralPath $constantsPath -PathType Leaf)) {
        throw ('缺少版本来源文件：{0}' -f $constantsPath)
    }

    . $constantsPath
    $value = Get-WinstProductVersion
    if (-not $value) {
        throw ('{0} 里的 Get-WinstProductVersion 没有返回值' -f $constantsPath)
    }
    return [string]$value
}

function Get-ProductVersionSourceRelative {
    <#
    .SYNOPSIS
        版本来源文件相对仓库根的路径，用于提示。
    #>
    return $constantsPath.Substring($repo.Length + 1)
}

function Get-WinstModuleDirectory {
    <#
    .SYNOPSIS
        列出 Modules\ 下的模块目录，按目录名排序。

    .DESCRIPTION
        一个目录算模块的条件：目录名与其中的清单同名，
        即 Modules\Winst.Foo\Winst.Foo.psd1。

    .OUTPUTS
        [System.IO.DirectoryInfo][]
    #>
    $result = New-Object 'System.Collections.Generic.List[object]'

    foreach ($dir in @(Get-ChildItem -LiteralPath $modulesDir -Directory -ErrorAction Stop | Sort-Object -Property Name)) {
        $manifest = Join-Path $dir.FullName ($dir.Name + '.psd1')
        if (Test-Path -LiteralPath $manifest -PathType Leaf) {
            $result.Add($dir)
        } else {
            throw ('Modules\{0} 不是模块目录：缺少同名清单 {0}.psd1' -f $dir.Name)
        }
    }

    if ($result.Count -eq 0) {
        throw ('{0} 下没有任何模块目录' -f $modulesDir)
    }
    return $result
}

function Get-FunctionNameFromPath {
    <#
    .SYNOPSIS
        用 AST 取出一个 .ps1 里定义的全部函数名（含嵌套定义）。
    #>
    param([string]$Path)

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$parseErrors)

    if ($parseErrors -and $parseErrors.Count -gt 0) {
        throw ('{0}: 语法错误：{1}（第 {2} 行）' -f $Path, $parseErrors[0].Message, $parseErrors[0].Extent.StartLineNumber)
    }

    $names = New-Object 'System.Collections.Generic.List[string]'
    $definitions = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
        }, $true)

    foreach ($definition in $definitions) {
        $names.Add($definition.Name)
    }
    return $names
}

function Get-SourceScriptFile {
    <#
    .SYNOPSIS
        取一棵源树里要进压缩包的脚本文件，并校验编码与换行。

    .DESCRIPTION
        .ps1 / .psm1 / .psd1 必须 UTF-8 with BOM + CRLF：
        Windows PowerShell 5.1 按系统 ANSI 读无 BOM 文件，中文会静默变乱码，
        而脚本本身看起来仍能跑，问题要到用户机器上才暴露。

        这里只校验、不修正：源文件格式是开发者的事，构建发现问题就该拦下来。

    .OUTPUTS
        [System.IO.FileInfo[]] 全部脚本文件
    #>
    param(
        [string]$Root,
        [string[]]$AdditionalFile = @()
    )

    $files = New-Object 'System.Collections.Generic.List[object]'
    $missingBom = New-Object 'System.Collections.Generic.List[string]'
    $badNewline = New-Object 'System.Collections.Generic.List[string]'

    $scriptFiles = @(Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction Stop |
            Where-Object { @('.ps1', '.psm1', '.psd1') -contains $_.Extension.ToLowerInvariant() })
    foreach ($path in @($AdditionalFile)) {
        if (-not $path) { continue }
        $file = Get-Item -LiteralPath $path -Force -ErrorAction Stop
        if (@('.ps1', '.psm1', '.psd1') -notcontains $file.Extension.ToLowerInvariant()) {
            throw ('附加源文件不是 PowerShell 脚本：{0}' -f $file.FullName)
        }
        $scriptFiles += $file
    }

    foreach ($file in @($scriptFiles | Sort-Object -Property FullName)) {

        $bytes = [IO.File]::ReadAllBytes($file.FullName)
        $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)

        if (-not $hasBom) {
            $missingBom.Add($file.FullName)
            $text = [Text.Encoding]::UTF8.GetString($bytes)
        } else {
            $text = [Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
        }

        if ($text -match "(?<!`r)`n") {
            $badNewline.Add($file.FullName)
        }

        $files.Add($file)
    }

    if ($missingBom.Count -gt 0 -or $badNewline.Count -gt 0) {
        $lines = New-Object 'System.Collections.Generic.List[string]'

        if ($missingBom.Count -gt 0) {
            $lines.Add(('缺少 UTF-8 BOM（{0} 个）：Windows PowerShell 5.1 会按系统 ANSI 读，中文变乱码。' -f $missingBom.Count))
            foreach ($path in $missingBom) { $lines.Add('    ' + $path) }
        }
        if ($badNewline.Count -gt 0) {
            if ($lines.Count -gt 0) { $lines.Add('') }
            $lines.Add(('换行不是 CRLF（{0} 个）：' -f $badNewline.Count))
            foreach ($path in $badNewline) { $lines.Add('    ' + $path) }
        }

        $lines.Add('')
        $lines.Add('源文件编码与换行由开发者保证，构建不会自动改写。')
        $lines.Add('请在编辑器里把上述文件另存为「UTF-8 with BOM」并使用 CRLF 换行后重新构建。')

        throw ($lines -join [Environment]::NewLine)
    }

    return $files
}

function Get-BundleBody {
    <#
    .SYNOPSIS
        把一个源文件转成合并进 .psm1 的片段：去重复的 #Requires，结尾补齐 CRLF。
    #>
    param([string]$Path)

    $text = [IO.File]::ReadAllText($Path)

    # 每个函数文件都带 #Requires -Version 5.1；合并后只需文件顶部一条。
    $text = $text -replace '(?m)^[ \t]*#Requires[^\r\n]*\r?\n?', ''
    return $text.TrimEnd() + "`r`n"
}

function New-BundleText {
    <#
    .SYNOPSIS
        把各模块拼成单一 .psm1 的文本。

    .OUTPUTS
        @{ Text; PublicNames; LineMap }
    #>
    param(
        [Parameter(Mandatory = $true)]$Modules,
        [Parameter(Mandatory = $true)][string]$Version
    )

    $builder = New-Object System.Text.StringBuilder
    $lineMap = New-Object 'System.Collections.Generic.List[object]'
    $publicNames = New-Object 'System.Collections.Generic.List[string]'
    $ownerByFunction = New-Object 'System.Collections.Generic.Dictionary[string, string]' ([StringComparer]::Ordinal)
    $duplicates = New-Object 'System.Collections.Generic.List[string]'
    $line = 0

    $header = @(
        '#Requires -Version 5.1'
        '<#'
        ('    winst 运行时（单一模块形态）  v{0}' -f $Version)
        ''
        '    由 build.ps1 生成，不要手工编辑。'
        ''
        '    内容按模块目录名的顺序合并（Modules\ 下每个目录一个模块）；'
        '    每个模块内先 Private\ 再 Public\，各自按路径排序。'
        '    顺序不影响正确性：函数文件只定义函数，加载期没有互相调用。'
        '    导出名单在构建期算好，加载时不再扫描源文件。'
        ''
        '    开发时改 Modules\Winst.*\ 下的函数文件，然后重新构建；'
        '    winst.ps1 在开发树里按目录发现模块并逐个导入，不读本文件。'
        '#>'
        ''
        'Set-StrictMode -Version 2'
        ''
    )
    foreach ($text in $header) {
        [void]$builder.Append($text + "`r`n")
        $line++
    }

    foreach ($moduleDir in $Modules) {
        $moduleName = $moduleDir.Name

        foreach ($role in @('Private', 'Public')) {
            $roleDir = Join-Path $moduleDir.FullName $role
            if (-not (Test-Path -LiteralPath $roleDir -PathType Container)) { continue }

            foreach ($file in @(Get-ChildItem -LiteralPath $roleDir -Filter '*.ps1' -File -Recurse -ErrorAction Stop |
                        Sort-Object -Property FullName)) {

                $relative = $file.FullName.Substring($repo.Length + 1).Replace('\', '/')
                $lineMap.Add([pscustomobject]@{ Start = $line + 1; Path = $file.FullName })

                # 每个片段前面加一行来源注释：合并后仍能一眼看出函数出自哪个文件。
                $banner = ('# ==== {0} ====' -f $relative) + "`r`n"
                [void]$builder.Append($banner)
                $line++

                $body = Get-BundleBody -Path $file.FullName
                [void]$builder.Append($body)
                $line += ([regex]::Matches($body, "`n")).Count

                $names = @(Get-FunctionNameFromPath -Path $file.FullName)
                foreach ($name in $names) {
                    if ($ownerByFunction.ContainsKey($name)) {
                        $duplicates.Add(('{0}（{1} 与 {2}）' -f $name, $ownerByFunction[$name], $relative))
                    } else {
                        $ownerByFunction[$name] = $relative
                    }
                }

                if ($role -eq 'Public') {
                    foreach ($name in $names) { $publicNames.Add($name) }
                }
            }
        }

        if (-not (Test-Path -LiteralPath (Join-Path $moduleDir.FullName 'Public') -PathType Container)) {
            throw ('模块 {0} 没有 Public\ 目录，合并后不会有任何可导出的函数' -f $moduleName)
        }
    }

    if ($duplicates.Count -gt 0) {
        throw ('函数重名，无法合并成单一模块：' + [Environment]::NewLine + (($duplicates | ForEach-Object { '    ' + $_ }) -join [Environment]::NewLine))
    }

    $unique = @($publicNames | Select-Object -Unique)
    if ($unique.Count -eq 0) {
        throw '没有可导出的函数：所有模块的 Public\ 都是空的'
    }

    [void]$builder.Append("`r`n")
    $line++
    [void]$builder.Append('Export-ModuleMember -Function @(' + "`r`n")
    $line++
    foreach ($name in $unique) {
        [void]$builder.Append(("    '{0}'" -f $name) + "`r`n")
        $line++
    }
    [void]$builder.Append(')' + "`r`n")
    $line++

    return @{
        Text        = $builder.ToString()
        PublicNames = $unique
        LineMap     = $lineMap
    }
}

function Resolve-BundleOrigin {
    <#
    .SYNOPSIS
        把合并文本里的行号映射回源文件，便于报语法错误。
    #>
    param($LineMap, [int]$Line)

    $current = $null
    foreach ($entry in $LineMap) {
        if ($entry.Start -le $Line) { $current = $entry } else { break }
    }
    if (-not $current) { return '' }
    return ('（来自 {0}）' -f $current.Path)
}

function New-BundleManifestText {
    <#
    .SYNOPSIS
        生成单一模块的 .psd1。
    #>
    param([Parameter(Mandatory = $true)][string]$Version)

    $parsed = $null
    if (-not [version]::TryParse($Version, [ref]$parsed)) {
        throw ('产品版本 {0} 不是 <主>.<次>.<修订> 形式，无法写进 ModuleVersion；请修正 Get-WinstProductVersion' -f $Version)
    }

    return @"
@{
    RootModule           = '$bundleName.psm1'
    ModuleVersion        = '$($parsed.ToString())'
    GUID                 = '2c5a7f34-3b9e-4c86-9d21-5f0d8a6b17e2'
    Author               = 'winst'
    CompanyName          = 'winst'
    Copyright            = '(c) winst'
    Description          = 'winst 运行时（单一模块形态，由 build.ps1 生成）：下载、安装、更新、卸载、批量部署。'
    PowerShellVersion    = '5.1'
    CompatiblePSEditions = @('Desktop')

    # 导出名单由 .psm1 末尾的 Export-ModuleMember 决定。
    FunctionsToExport    = '*'
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    # 依赖顺序已经体现在合并后的 .psm1 里，不需要 RequiredModules。
    # 刻意不用：那会让 Import-Module 去 PSModulePath 找模块，破坏「解压到任意目录即可运行」。
    PrivateData = @{
        PSData = @{
            Tags = @('winst', 'powershell51')
        }
    }
}
"@
}

function Write-Utf8BomFile {
    <#
    .SYNOPSIS
        写 UTF-8 with BOM + CRLF 的文本文件。
    #>
    param([string]$Path, [string]$Text)

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop
    }

    $normalized = ($Text -replace "`r`n", "`n") -replace "`n", "`r`n"
    [IO.File]::WriteAllText($Path, $normalized, (New-Object System.Text.UTF8Encoding($true)))
}

# -------------------------------------------------------------- 1. 版本与模块

try {
    $version = Get-ProductVersion
    $modules = Get-WinstModuleDirectory

    Write-Host ('  产品版本   : {0}（来自 {1} -> Get-WinstProductVersion）' -f $version, (Get-ProductVersionSourceRelative)) -ForegroundColor Gray
    Write-Host ('  模块       : {0} 个（按目录名排序）' -f $modules.Count) -ForegroundColor Gray

    # ------------------------------------------------- 模块目录结构一致性
    $problems = New-Object 'System.Collections.Generic.List[string]'
    foreach ($dir in $modules) {
        foreach ($suffix in @('.psd1', '.psm1')) {
            $expected = Join-Path $dir.FullName ($dir.Name + $suffix)
            if (-not (Test-Path -LiteralPath $expected -PathType Leaf)) {
                $problems.Add(('模块 {0} 缺少 {1}' -f $dir.Name, $suffix))
            }
        }
        if (-not (Test-Path -LiteralPath (Join-Path $dir.FullName 'Public') -PathType Container)) {
            $problems.Add(('模块 {0} 缺少 Public\ 目录' -f $dir.Name))
        }
    }
    if ($problems.Count -gt 0) {
        throw ($problems -join [Environment]::NewLine)
    }

    # ------------------------------------------------------- 源文件编码与换行
    # 只校验、不修正：源文件格式由开发者保证，不合规就拦住构建。
    $sourceFiles = @(Get-SourceScriptFile -Root $modulesDir -AdditionalFile (Join-Path $repo 'winst.ps1'))
    Write-Host ('  源文件     : Modules\ 与入口共 {0} 个脚本（BOM / CRLF 校验通过）' -f $sourceFiles.Count) -ForegroundColor Gray

    # ------------------------------------------- 一行安装脚本：必须无 BOM、无 #Requires
    # install.ps1 是唯一走 `irm | iex` 的文件：文本原样进 iex 解析，前导 U+FEFF 会被
    # 当成命令名的一部分（`?#Requires : 无法将“?#Requires”项识别为 cmdlet`）。
    # 那句报错不中断后续语句，于是表现为「装成功 + 一条报错」，必须在这里拦住。
    $installScript = Join-Path $repo 'install.ps1'
    if (Test-Path -LiteralPath $installScript -PathType Leaf) {
        $installBytes = [IO.File]::ReadAllBytes($installScript)
        $installProblems = New-Object 'System.Collections.Generic.List[string]'
        if ($installBytes.Length -ge 3 -and $installBytes[0] -eq 0xEF -and $installBytes[1] -eq 0xBB -and $installBytes[2] -eq 0xBF) {
            $installProblems.Add('install.ps1 带了 UTF-8 BOM。它通过 irm | iex 执行，BOM 会变成命令名的一部分并报错；请存成 UTF-8 无 BOM。')
        }
        $installText = [Text.Encoding]::UTF8.GetString($installBytes)
        if ($installText -match '(?im)^[ \t]*#Requires') {
            $installProblems.Add('install.ps1 里有 #Requires。无 BOM 时 iex 会忽略它，有 BOM 时会直接报错；一行安装脚本不需要它。')
        }
        if ($installText -match "(?<!`r)`n") {
            $installProblems.Add('install.ps1 的换行不是 CRLF。')
        }
        if ($installProblems.Count -gt 0) {
            throw ($installProblems -join [Environment]::NewLine)
        }
        Write-Host '  一行安装   : install.ps1 无 BOM / 无 #Requires（irm | iex 校验通过）' -ForegroundColor Gray
    }

    # --------------------------------------------------------- 2. 合并模块
    $bundle = New-BundleText -Modules $modules -Version $version

    $tokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput(
        $bundle.Text, 'Winst.psm1', [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors -and $parseErrors.Count -gt 0) {
        $first = $parseErrors[0]
        $origin = Resolve-BundleOrigin -LineMap $bundle.LineMap -Line $first.Extent.StartLineNumber
        throw ('合并后的 Winst.psm1 有语法错误：第 {0} 行 {1} {2}' -f $first.Extent.StartLineNumber, $first.Message, $origin)
    }

    Write-Host ('  合并结果   : {0} 个导出函数，{1:N0} 字节' -f $bundle.PublicNames.Count, $bundle.Text.Length) -ForegroundColor Gray

    # ------------------------------------------------------ manifest 版本
    $manifestPath = Join-Path $repo 'manifest.json'
    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        $catalogVersion = ''
        try {
            $catalog = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json
            if ($null -ne $catalog.PSObject.Properties['_manifestVersion']) {
                $catalogVersion = [string]$catalog._manifestVersion
            }
        } catch {
            $catalogVersion = ''
        }
        if ($catalogVersion -and $catalogVersion -ne $version) {
            Write-Host ('  提示       : manifest.json 的 _manifestVersion 是 {0}（软件源目录自己的版本，只在改清单时更新）' -f $catalogVersion) -ForegroundColor DarkYellow
        }
    }
}
catch {
    Write-Host ''
    Write-Host ('  [x] 构建中止：{0}' -f $_.Exception.Message) -ForegroundColor Red
    Write-Host ''
    exit 1
}

# ------------------------------------------------------------- 3. 铺构建树
# 先在临时目录里铺好并冒烟，全部通过后再落到 dist\（dist\ 在这次构建开始时已清空）。

$staging = Join-Path ([IO.Path]::GetTempPath()) ('winst-build-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))

try {
    $null = New-Item -ItemType Directory -Path $staging -Force -ErrorAction Stop

    $payload = @('winst.ps1', 'winst.cmd', 'LICENSE')
    foreach ($name in $payload) {
        $source = Join-Path $repo $name
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            throw ('缺少必需文件：{0}' -f $source)
        }
        # LICENSE 保持原样逐字节复制：它是许可证原文，不做编码或换行改写。
        Copy-Item -LiteralPath $source -Destination (Join-Path $staging $name) -Force -ErrorAction Stop
    }

    $bundleDir = Join-Path $staging ('Modules\' + $bundleName)
    $null = New-Item -ItemType Directory -Path $bundleDir -Force -ErrorAction Stop

    $bundleModulePath = Join-Path $bundleDir ($bundleName + '.psm1')
    $bundleManifestPath = Join-Path $bundleDir ($bundleName + '.psd1')
    Write-Utf8BomFile -Path $bundleModulePath -Text $bundle.Text
    Write-Utf8BomFile -Path $bundleManifestPath -Text (New-BundleManifestText -Version $version)

    # 生成的两个文件用「源码里最新的修改时间」做时间戳：
    # 源码没变时重复构建得到同一个 zip，便于核对 sha512。
    $stamp = (Get-Item -LiteralPath (Join-Path $repo 'winst.ps1')).LastWriteTime
    foreach ($file in $sourceFiles) {
        if ($file.LastWriteTime -gt $stamp) { $stamp = $file.LastWriteTime }
    }
    foreach ($path in @($bundleModulePath, $bundleManifestPath)) {
        (Get-Item -LiteralPath $path).LastWriteTime = $stamp
    }

    # --------------------------------------------------------- 4. 冒烟启动
    # 真正跑一次构建树里的入口：能起来、版本对得上，才往 dist\ 落。

    $probeScript = Join-Path $staging 'winst.ps1'
    $probeOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $probeScript -v 2>&1
    $probeExit = $LASTEXITCODE
    $probeText = (@($probeOutput) | ForEach-Object { [string]$_ }) -join [Environment]::NewLine

    if ($probeExit -ne 0) {
        throw ('构建树启动失败（退出码 {0}）：{1}{2}{3}' -f $probeExit, $probeText, [Environment]::NewLine, $probeScript)
    }
    if ($probeText.Trim() -ne $version) {
        throw ('构建树报出的版本与产品版本不一致：期望 {0}，实际 {1}' -f $version, $probeText.Trim())
    }

    Write-Host ('  冒烟启动   : winst.ps1 -v -> {0}' -f $probeText.Trim()) -ForegroundColor Gray

    # ------------------------------------------------- 5. 复制测试用清单
    # 发布树与压缩包都从这棵树来，所以清单必须在打包之前就位：
    # 产物目录因此可以直接当「脚本同目录」测本地软件源条目，不必额外拷文件。
    # 它只是本地测试数据，打包时跳过（见下一步），release 资产保持干净。
    $repoManifestPath = Join-Path $repo 'manifest.json'
    $testManifestPath = Join-Path $staging 'manifest.json'
    if (Test-Path -LiteralPath $repoManifestPath -PathType Leaf) {
        Copy-Item -LiteralPath $repoManifestPath -Destination $testManifestPath -Force -ErrorAction Stop
    }

    # ------------------------------------------------------------ 6. 打压缩包
    # 压缩的是刚冒烟通过的构建树。产物先落在临时文件里，
    # 全部校验通过后才放进 dist\。
    Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop

    # 临时文件与发布树都在 dist\ 下，先把目录建好。
    if (-not (Test-Path -LiteralPath $dist -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $dist -Force -ErrorAction Stop
    }

    if (Test-Path -LiteralPath $zipTemp -PathType Leaf) {
        Remove-Item -LiteralPath $zipTemp -Force -ErrorAction Stop
    }

    $archive = [IO.Compression.ZipFile]::Open($zipTemp, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in @(Get-ChildItem -LiteralPath $staging -Recurse -File -ErrorAction Stop | Sort-Object -Property FullName)) {
            $entryName = $file.FullName.Substring($staging.Length + 1).Replace('\', '/')
            # 测试用清单不进 release：它只用于在产物目录里测本地软件源
            if ($entryName -eq 'manifest.json') { continue }
            $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive,
                $file.FullName,
                $entryName,
                [IO.Compression.CompressionLevel]::Optimal)
        }
    } finally {
        $archive.Dispose()
    }

    # --------------------------------------------------------------- 6. 校验
    $archive = [IO.Compression.ZipFile]::OpenRead($zipTemp)
    try {
        $entries = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
    } finally {
        $archive.Dispose()
    }

    foreach ($required in @(
            'winst.ps1'
            'winst.cmd'
            'LICENSE'
            ('Modules/{0}/{0}.psd1' -f $bundleName)
            ('Modules/{0}/{0}.psm1' -f $bundleName))) {
        if ($entries -notcontains $required) {
            throw ('压缩包里缺少必需条目：{0}' -f $required)
        }
    }

    foreach ($forbidden in @('manifest.json', 'build.cmd', 'build.ps1', 'install.ps1', 'README.md')) {
        if ($entries -contains $forbidden) {
            throw ('压缩包里不该有 {0}：它不是运行时文件' -f $forbidden)
        }
    }
    if (@($entries | Where-Object { $_ -like 'docs/*' }).Count -gt 0) {
        throw '压缩包里不该有 docs\：文档不进 release'
    }

    # 解压后应直接得到 winst 目录内容，不能再套一层 winst\。
    $top = @($entries | ForEach-Object { ($_ -split '/')[0] } | Sort-Object -Unique)
    if ($top.Count -eq 1 -and $top[0] -match '^winst') {
        throw ('压缩包多套了一层顶层目录：{0}' -f $top[0])
    }

    # -------------------------------------------------- 7. 落地发布树与压缩包
    # dist\ 在构建开始时已清空，这里直接放本次产物。
    # 先放树再放 zip，这样 dist\winst\ 与 dist\winst.zip 永远对得上。

    if (-not (Test-Path -LiteralPath $dist -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $dist -Force -ErrorAction Stop
    }

    Move-Item -LiteralPath $staging -Destination $releaseDir -Force -ErrorAction Stop
    Move-Item -LiteralPath $zipTemp -Destination $zipPath -Force -ErrorAction Stop

    # ------------------------------------------------------------ 8. 算摘要
    # 用 .NET 直接算：cmd 里 chcp 936 时 Get-FileHash 偶发取不到（cmdlet 解析问题）。
    $sha = [Security.Cryptography.SHA512]::Create()
    try {
        $stream = [IO.File]::OpenRead($zipPath)
        try { $bytes = $sha.ComputeHash($stream) } finally { $stream.Dispose() }
    } finally {
        $sha.Dispose()
    }
    $hash = ([BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant()

    [IO.File]::WriteAllText($sidecar, ('{0}  winst.zip' -f $hash) + "`r`n", (New-Object System.Text.ASCIIEncoding))
}
catch {
    Write-Host ''
    Write-Host ('  [x] 构建中止：{0}' -f $_.Exception.Message) -ForegroundColor Red
    Write-Host ''
    exit 1
}
finally {
    foreach ($path in @($staging, $zipTemp)) {
        try {
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
            }
        } catch { }
    }
}

# ------------------------------------------------------------------ 9. 汇总
Write-Host ''
Write-Host ('  发布树     : {0}' -f $releaseDir) -ForegroundColor Green
Write-Host ('  发布树大小 : {0:N0} 字节' -f (@(Get-ChildItem -LiteralPath $releaseDir -Recurse -File | Measure-Object -Property Length -Sum).Sum)) -ForegroundColor Gray
if (Test-Path -LiteralPath (Join-Path $releaseDir 'manifest.json') -PathType Leaf) {
    Write-Host '  测试清单   : 已复制到发布树（仅用于本地测试，不在压缩包里）' -ForegroundColor DarkYellow
}
Write-Host ('  压缩包     : {0}' -f $zipPath) -ForegroundColor Green
Write-Host ('  压缩包大小 : {0:N0} 字节' -f (Get-Item -LiteralPath $zipPath).Length) -ForegroundColor Gray
Write-Host ('  条目       : {0}' -f $entries.Count) -ForegroundColor Gray
Write-Host ('  导出函数   : {0}' -f $bundle.PublicNames.Count) -ForegroundColor Gray
Write-Host ('  sha512     : {0}' -f $hash) -ForegroundColor DarkGray
Write-Host ('  校验文件   : {0}' -f $sidecar) -ForegroundColor Gray
Write-Host ''
Write-Host ('  试跑产物   : {0}' -f (Join-Path $releaseDir 'winst.cmd')) -ForegroundColor Cyan
Write-Host ('  版本号来源 : {0} -> Get-WinstProductVersion（发版前自行修改，tag 用 v{1}）' -f (Get-ProductVersionSourceRelative), $version) -ForegroundColor Cyan
Write-Host ('  下一步     : 把 dist\winst.zip 与 dist\winst.zip.sha512 作为 release 资产上传。') -ForegroundColor Cyan
Write-Host ''

if ($interactive) {
    Read-Host '构建完成，按回车关闭' | Out-Null
}

exit 0
