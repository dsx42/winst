#Requires -Version 5.1

function Assert-WinstSelfPackage {
    <#
    .SYNOPSIS
        检查暂存的 winst 运行入口、模块清单、加载器及脚本语法。
    #>
    param([string]$StageDir)

    foreach ($required in @('winst.ps1', 'winst.cmd', 'LICENSE')) {
        if (-not (Test-WinstFileSystemPath -Path (Join-WinstPath $StageDir $required) -PathType Leaf)) {
            throw ('winst 安装包缺少 ' + $required)
        }
    }
    $stagedModules = Join-WinstPath $StageDir 'Modules'
    if (-not (Test-WinstFileSystemPath -Path $stagedModules -PathType Container)) { throw 'winst 安装包里没有 Modules 目录' }
    $moduleDirs = @(Get-WinstChildItem -Path $stagedModules -ErrorAction Stop | Where-Object { $_.PSIsContainer })
    if ($moduleDirs.Count -eq 0) { throw 'winst 安装包没有模块目录' }
    $sharedLoader = Join-WinstPath $stagedModules 'Import-WinstFunctionFiles.ps1'
    $hasSharedLoader = Test-WinstFileSystemPath -Path $sharedLoader -PathType Leaf
    foreach ($moduleDir in $moduleDirs) {
        $manifestPath = Join-WinstPath $moduleDir.FullName ($moduleDir.Name + '.psd1')
        $modulePath = Join-WinstPath $moduleDir.FullName ($moduleDir.Name + '.psm1')
        if (-not (Test-WinstFileSystemPath -Path $manifestPath -PathType Leaf) -or
            -not (Test-WinstFileSystemPath -Path $modulePath -PathType Leaf)) {
            throw ('winst 模块目录缺少同名清单或加载器：' + $moduleDir.FullName)
        }
        if (-not $hasSharedLoader -and (Select-String -LiteralPath (ConvertTo-WinstExtendedPath $modulePath) -Quiet -Pattern '^\s*\.\s+.*[\\/]Import-WinstFunctionFiles\.ps1["'']?(?:\s|$)')) {
            throw ('winst 安装包缺少模块加载器依赖：' + $sharedLoader)
        }
        $null = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop
    }
    $scripts = @((Join-WinstPath $StageDir 'winst.ps1')) + @(Get-WinstChildItem -Path $stagedModules -Recurse -File -ErrorAction Stop |
        Where-Object { [IO.Path]::GetExtension($_.Name) -in @('.ps1', '.psm1', '.psd1') } | ForEach-Object { $_.FullName })
    foreach ($scriptFile in $scripts) {
        $parseErrors = $null
        $null = [Management.Automation.Language.Parser]::ParseFile($scriptFile, [ref]$null, [ref]$parseErrors)
        if ($parseErrors) { throw ('安装包脚本语法错误（{0}）：{1}' -f $scriptFile, $parseErrors[0].Message) }
    }
}
