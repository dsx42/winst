#Requires -Version 5.1

function New-WinstPortableBlocks {
    <#
    .SYNOPSIS
        免安装条目（portable / file）的 ② 安装 定义。
    .OUTPUTS
        @{ Install; ShortcutName; Notes }
    #>
    param($Entry, [string]$Version, [string]$Type, [string]$DisplayName, $FileList, $CopyList, [bool]$Desktop, [bool]$StartMenu)

    $notes = @()
    $stripTopDir = ConvertTo-WinstStripTopDirValue `
        -Value (Get-EntryValue -Entry $Entry -Key 'stripTopDir' -Default $null)

    $portableMode = (Get-EntryString -Entry $Entry -Key 'portableMode').Trim().ToLowerInvariant()
    if ($portableMode -ne 'overwrite') { $portableMode = 'clean' }

    $keepList = @()
    foreach ($item in @(Get-EntryArray -Entry $Entry -Key 'keep')) {
        if ($null -eq $item) { continue }
        $text = Expand-VersionPlaceholder -Text ([string]$item) -Version $Version
        if ($text.Trim()) { $keepList += $text.Trim() }
    }

    $primaryName = ''
    if (@($FileList).Count -gt 0) { $primaryName = Get-EntryString -Entry $FileList[0] -Key 'name' }

    if ($Type -eq 'portable') {
        # extractFiles：只从主包里取这几个相对路径（文件 / 目录）——引擎包用它"只取 7z.exe + 7z.dll"，
        # 不必把官方 7-Zip 安装包里的 GUI / 语言文件一起落地
        $extractFiles = @()
        foreach ($item in @(Get-EntryArray -Entry $Entry -Key 'extractFiles')) {
            $text = ([string]$item).Trim().Trim('\', '/')
            if ($text) { $extractFiles += $text }
        }
        $installBlock = [ordered]@{
            method       = 'portable'
            stripTopDir  = $stripTopDir
            portableMode = $portableMode
            keep         = $keepList
            extractFiles = $extractFiles
            mainExe      = Expand-VersionPlaceholder -Text (Get-EntryString -Entry $Entry -Key 'mainExe') -Version $Version
        }
    } else {
        # file（exe 同义）：主程序 = 主包落位文件；被 postInstallCopy 改名后即改名结果
        $mainExe = $primaryName
        foreach ($rule in @($CopyList)) {
            if (-not [bool]$rule['move']) { continue }
            $fromRule = ([string]$rule['from']).Trim()
            if ($primaryName -and $fromRule -ieq $primaryName) {
                $mainExe = Get-FileNameFromUrl -Url ([string]$rule['to'])
                break
            }
        }
        if (Get-EntryString -Entry $Entry -Key 'mainExe') {
            $notes += '这是单文件条目，主程序自动取下载下来的那个文件（改名后取改名结果）；软件源里的 mainExe 已忽略'
        }
        $installBlock = [ordered]@{
            method  = 'file'
            mainExe = $mainExe
        }
    }

    $shortcutName = ''
    if ($Desktop -or $StartMenu) { $shortcutName = ConvertTo-ShortcutName -Name $DisplayName }

    return @{ Install = $installBlock; ShortcutName = $shortcutName; Notes = $notes }
}
