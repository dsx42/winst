#Requires -Version 5.1

function New-WinstInstallerBlocks {
    <#
    .SYNOPSIS
        安装版条目的 ② 安装 / ⑦ 卸载 定义（应用包 msix 与压缩包 installerExe 的差异都在这里）。
    .OUTPUTS
        @{ Install; Uninstall; Notes; Error }
    #>
    param($Entry, [string]$Version, $FileList, $DetectBlock)

    $notes = @()
    $installBlock = [ordered]@{
        method        = 'installer'
        installArgs   = Expand-VersionPlaceholder -Text (Get-EntryString -Entry $Entry -Key 'installArgs') -Version $Version
        uninstallArgs = Expand-VersionPlaceholder -Text (Get-EntryString -Entry $Entry -Key 'uninstallArgs') -Version $Version
    }
    if (-not (Test-WinstArgumentTemplateSafe -Value ([string]$installBlock['installArgs']))) {
        return @{ Install = $installBlock; Uninstall = $null; Notes = @(); Error = 'installArgs 含有控制字符或未闭合的双引号' }
    }

    # 主包本身是压缩包（如 Chocolatey 的 .nupkg）时：声明 installerExe 表示「先解压主包，再运行包内的安装程序」，
    # 解压规则用同一条 stripTopDir（字符串可指向包内子目录 / 单个文件）
    $installerExeRel = Expand-VersionPlaceholder -Text (Get-EntryString -Entry $Entry -Key 'installerExe') -Version $Version
    if ($installerExeRel) {
        $validationRoot = Join-WinstPath ([IO.Path]::GetTempPath()) 'winst-manifest-path-check'
        $installerCheck = Resolve-WinstSafeChildPattern -Root $validationRoot -Child $installerExeRel -Label 'installerExe'
        if (-not $installerCheck.Ok) {
            return @{ Install = $installBlock; Uninstall = $null; Notes = @(); Error = [string]$installerCheck.Error }
        }
        $installBlock['stripTopDir'] = ConvertTo-WinstStripTopDirValue `
            -Value (Get-EntryValue -Entry $Entry -Key 'stripTopDir' -Default $null)
        $installBlock['installerExe'] = $installerExeRel
    }
    $uninstallBlock = [ordered]@{
        method        = 'registry'
        name          = [string]$DetectBlock['name']
        uninstallArgs = [string]$installBlock['uninstallArgs']
    }

    # 主包是应用包（msixbundle 等）：安装交给系统自带的应用包安装（Add-AppxPackage），
    # 卸载也从系统应用包记录里移除，不走注册表卸载项
    $isAppxInstall = $false
    $mainPackageName = ''
    if (@($FileList).Count -gt 0) {
        $mainPackageName = Get-EntryString -Entry $FileList[0] -Key 'name'
        if (-not $mainPackageName) { $mainPackageName = Get-FileNameFromUrl -Url ([string]$FileList[0]['url']) }
    }
    if ($mainPackageName) {
        $mainExt = ''
        try { $mainExt = [IO.Path]::GetExtension($mainPackageName).ToLowerInvariant() } catch { $mainExt = '' }
        if (@('.msix', '.msixbundle', '.appx', '.appxbundle') -contains $mainExt) { $isAppxInstall = $true }
    }
    if ($isAppxInstall) {
        $installBlock['appx'] = $true
        if ([string]$installBlock['installArgs']) {
            $notes += '应用包安装不使用安装参数，软件源里的 installArgs 已忽略'
        }
    }
    # 卸载：主包是应用包，或版本检测走的就是系统应用包记录（如 Windows App Runtime 的安装器会把运行时装成应用包）。
    # 卸载名称规则可声明为字符串或数组，覆盖 detect.name；解析时展开版本占位符并逐条校验，
    # 让清单按目标产品系列和通道明确限定范围，共享组件是否移除同样由规则决定。
    if ($isAppxInstall -or (Get-EntryString -Entry $DetectBlock -Key 'method') -eq 'appx') {
        $entryUninstall = Get-EntryValue -Entry $Entry -Key 'uninstall' -Default $null
        $uninstallName = Get-EntryValue -Entry $entryUninstall -Key 'name' -Default $null
        if ($null -eq $uninstallName) { $uninstallName = Get-EntryValue -Entry $DetectBlock -Key 'name' -Default '' }
        $nameRules = New-WinstAppxUninstallNameRules -NameRules $uninstallName -Version $Version
        if ($nameRules.Error) { return @{ Install = $installBlock; Uninstall = $null; Notes = @(); Error = [string]$nameRules.Error } }
        $uninstallBlock = [ordered]@{
            method        = 'appx'
            name          = $nameRules.Value
            uninstallArgs = ''
        }
    }
    $ignoredFields = @()
    foreach ($key in @('stripTopDir', 'portableMode', 'keep', 'mainExe', 'addToPath', 'env', 'shortcuts', 'postInstallCopy', 'postInstall')) {
        # 主包是压缩包（声明了 installerExe）时，stripTopDir 是解压规则、不是「多余设置」
        if ($key -eq 'stripTopDir' -and $installerExeRel) { continue }
        $value = Get-EntryValue -Entry $Entry -Key $key -Default $null
        if ($null -eq $value) { continue }
        $isEmpty = $false
        if ($value -is [bool]) { $isEmpty = $false }
        elseif ($value -is [string]) { $isEmpty = -not ([string]$value).Trim() }
        else { $isEmpty = (@($value).Count -eq 0) }
        if (-not $isEmpty) { $ignoredFields += $key }
    }
    if ($ignoredFields.Count -gt 0) {
        $notes += ('这是安装版软件，安装位置和系统设置都由安装程序自己管理；软件源里多余的 {0} 设置已忽略' -f ($ignoredFields -join '、'))
    }

    return @{ Install = $installBlock; Uninstall = $uninstallBlock; Notes = $notes; Error = '' }
}
