#Requires -Version 5.1
<#
    将开发模块合并为发布树，运行入口冒烟，生成 winst.zip 和 SHA512。
    源脚本须为 UTF-8 BOM + CRLF，引导脚本 install.ps1 使用无 BOM 的 UTF-8。
    运行 build.cmd 即可构建。CI=1 或 -NoPause 可跳过结尾等待。
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

function Get-FunctionNameFromText {
    <#
    .SYNOPSIS
        用 AST 取出一个 .ps1 里定义的全部函数名（含嵌套定义）。
    #>
    param([string]$Path, [string]$Text)

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Text, $Path, [ref]$tokens, [ref]$parseErrors)

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
    $badUtf8 = New-Object 'System.Collections.Generic.List[string]'
    $strictUtf8 = New-Object Text.UTF8Encoding($false, $true)

    $scriptFiles = @(Get-ChildItem -LiteralPath $Root -Recurse -File -ErrorAction Stop |
            Where-Object { @('.ps1', '.psm1', '.psd1') -contains $_.Extension.ToLowerInvariant() })
    $scriptFiles += @(Get-Item -LiteralPath $AdditionalFile -ErrorAction Stop)

    foreach ($file in @($scriptFiles | Sort-Object -Property FullName)) {

        $bytes = [IO.File]::ReadAllBytes($file.FullName)
        $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)

        if (-not $hasBom) { $missingBom.Add($file.FullName) }
        try { $text = $strictUtf8.GetString($bytes) }
        catch { $badUtf8.Add($file.FullName); continue }
        if ($text -match "(?<!`r)`n") {
            $badNewline.Add($file.FullName)
        }

        $files.Add($file)
    }

    if ($missingBom.Count -gt 0 -or $badNewline.Count -gt 0 -or $badUtf8.Count -gt 0) {
        $lines = New-Object 'System.Collections.Generic.List[string]'

        if ($badUtf8.Count -gt 0) {
            $lines.Add('含有非法 UTF-8 字节：')
            foreach ($path in $badUtf8) { $lines.Add('    ' + $path) }
        }
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
    param([string]$Text)

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
    $ownerByFunction = New-Object 'System.Collections.Generic.Dictionary[string, string]' ([StringComparer]::OrdinalIgnoreCase)
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
        foreach ($role in @('Private', 'Public')) {
            $roleDir = Join-Path $moduleDir.FullName $role
            if ($role -eq 'Private' -and -not (Test-Path -LiteralPath $roleDir -PathType Container)) { continue }

            foreach ($file in @(Get-ChildItem -LiteralPath $roleDir -Filter '*.ps1' -File -Recurse -ErrorAction Stop |
                        Sort-Object -Property FullName)) {

                $relative = $file.FullName.Substring($repo.Length + 1).Replace('\', '/')
                $lineMap.Add([pscustomobject]@{ Start = $line + 1; Path = $file.FullName })

                # 每个片段前面加一行来源注释：合并后仍能一眼看出函数出自哪个文件。
                $banner = ('# ==== {0} ====' -f $relative) + "`r`n"
                [void]$builder.Append($banner)
                $line++

                $source = [IO.File]::ReadAllText($file.FullName)
                $body = Get-BundleBody -Text $source
                [void]$builder.Append($body)
                for ($pos = $body.IndexOf("`n"); $pos -ge 0; $pos = $body.IndexOf("`n", $pos + 1)) { $line++ }

                $names = @(Get-FunctionNameFromText -Path $file.FullName -Text $source)
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

    }

    if ($duplicates.Count -gt 0) {
        throw ('函数重名，无法合并成单一模块：' + [Environment]::NewLine + (($duplicates | ForEach-Object { '    ' + $_ }) -join [Environment]::NewLine))
    }

    $unique = $publicNames.ToArray()
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

    [IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding($true)))
}

# -------------------------------------------------------------- 1. 版本与模块

try {
    $version = Get-ProductVersion
    $versionSource = $constantsPath.Substring($repo.Length + 1)
    $modules = @(Get-ChildItem -LiteralPath $modulesDir -Directory -ErrorAction Stop | Sort-Object Name)
    if ($modules.Count -eq 0) { throw ('{0} 下没有任何模块目录' -f $modulesDir) }

    Write-Host ('  产品版本   : {0}（来自 {1} -> Get-WinstProductVersion）' -f $version, $versionSource) -ForegroundColor Gray
    Write-Host ('  模块       : {0} 个（按目录名排序）' -f $modules.Count) -ForegroundColor Gray

    # ------------------------------------------------- 模块目录结构一致性
    $problems = New-Object 'System.Collections.Generic.List[string]'
    if (-not (Test-Path -LiteralPath (Join-Path $modulesDir 'Import-WinstFunctionFiles.ps1') -PathType Leaf)) {
        $problems.Add('Modules 缺少开发树加载器 Import-WinstFunctionFiles.ps1')
    }
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
    $sourceFiles = @(Get-SourceScriptFile -Root $modulesDir -AdditionalFile @((Join-Path $repo 'winst.ps1'), (Join-Path $repo 'build.ps1')))
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
        $installText = ''
        try { $installText = (New-Object Text.UTF8Encoding($false, $true)).GetString($installBytes) }
        catch { $installProblems.Add('install.ps1 含有非法 UTF-8 字节。') }
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
    $tokens = $null
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
            $manifestText = (New-Object Text.UTF8Encoding($false, $true)).GetString([IO.File]::ReadAllBytes($manifestPath)).TrimStart([char]0xFEFF)
            if (-not $manifestText.Trim()) { throw '文件为空' }
            $catalog = $manifestText | ConvertFrom-Json -ErrorAction Stop

            if ($null -ne $catalog -and $null -ne $catalog.PSObject.Properties['_manifestVersion']) {
                $catalogVersion = [string]$catalog._manifestVersion
            }
        } catch {
            throw ('本地测试清单无法解析：{0}：{1}' -f $manifestPath, $_.Exception.Message)
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
    $manifestBody = (New-BundleManifestText -Version $version) -replace "(?<!`r)`n", "`r`n"
    Write-Utf8BomFile -Path $bundleManifestPath -Text $manifestBody

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

    # ------------------------------------------------------------ 6. 打压缩包
    # 压缩的是刚冒烟通过的构建树。产物先落在临时文件里，
    # 全部校验通过后才放进 dist\。
    Add-Type -AssemblyName System.IO.Compression -ErrorAction Stop
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop

    # 临时文件与发布树都在 dist\ 下，先把目录建好。
    if (-not (Test-Path -LiteralPath $dist -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $dist -Force -ErrorAction Stop
    }

    $members = $payload + @(('Modules/{0}/{0}.psd1' -f $bundleName), ('Modules/{0}/{0}.psm1' -f $bundleName))
    $archive = [IO.Compression.ZipFile]::Open($zipTemp, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($entryName in $members) {
            $null = [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $archive,
                (Join-Path $staging $entryName),
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

    if (Compare-Object -ReferenceObject $members -DifferenceObject $entries -CaseSensitive) {
        throw ('压缩包成员与发布清单不一致：{0}' -f ($entries -join '、'))
    }

    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        Copy-Item -LiteralPath $manifestPath -Destination (Join-Path $staging 'manifest.json') -ErrorAction Stop
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
Write-Host ('  版本号来源 : {0} -> Get-WinstProductVersion（发版前自行修改，tag 用 v{1}）' -f $versionSource, $version) -ForegroundColor Cyan
Write-Host ('  下一步     : 把 dist\winst.zip 与 dist\winst.zip.sha512 作为 release 资产上传。') -ForegroundColor Cyan
Write-Host ''

if ($interactive) {
    Read-Host '构建完成，按回车关闭' | Out-Null
}

exit 0
