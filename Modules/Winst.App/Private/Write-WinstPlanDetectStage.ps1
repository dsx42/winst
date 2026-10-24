#Requires -Version 5.1

function Write-WinstPlanDetectStage {
    <#
    .SYNOPSIS
        ⑥ 版本检测段（按 detect.method 生成说明文字）。
    #>
    param($Plan, [hashtable]$View, [string]$MainProgram = '')

    $installDir = $View.InstallDir
    $detect = Get-EntryValue -Entry $Plan -Key 'detect' -Default $null
    $detectLines = @()
    switch (Get-EntryString -Entry $detect -Key 'method') {
        'registry' {
            $detectLines += ('在系统的安装记录里按名称查找软件（名称规则: {0}）' -f (Get-EntryString -Entry $detect -Key 'name'))
        }
        'fileVersion' {
            $detectLines += ('读取这个文件的版本号: {0}' -f (Expand-PlanPlaceholders -Value (Get-EntryString -Entry $detect -Key 'pathGlob') -InstallDir $installDir -InstallRoot $View.InstallRoot))
        }
        'markerFile' {
            $detectLines += ('读取这个文件: {0}' -f (Expand-PlanPlaceholders -Value (Get-EntryString -Entry $detect -Key 'pathGlob') -InstallDir $installDir -InstallRoot $View.InstallRoot))
        }
        'jsonFile' {
            $detectLines += ('读取这个文件: {0}' -f (Expand-PlanPlaceholders -Value (Get-EntryString -Entry $detect -Key 'pathGlob') -InstallDir $installDir -InstallRoot $View.InstallRoot))
            $detectLines += ('版本号所在的字段: {0}' -f (Get-EntryString -Entry $detect -Key 'jsonKey'))
        }
        'appx' {
            $detectLines += ('在系统的应用包记录里按名称查找（名称规则: {0}）' -f (Get-EntryString -Entry $detect -Key 'name'))
        }
        'cliVersion' {
            # detect.exe 指定检测命令运行哪个程序：FluxDown 的主程序是
            # fluxdown-desktop.exe，而带 --version 输出的是同目录的 fluxdown_nmh.exe
            $programText = Expand-PlanPlaceholders -Value (Get-EntryString -Entry $detect -Key 'exe') -InstallDir $installDir -InstallRoot $View.InstallRoot
            if (-not $programText) { $programText = $MainProgram }
            if ($programText -and $installDir -and -not [IO.Path]::IsPathRooted($programText)) { $programText = Join-Path $installDir $programText }
            $argsText = Get-EntryString -Entry $detect -Key 'versionArgs'
            if (-not $argsText) { $argsText = '-v' }
            # jar 主程序要由 java 启动，展示的也应是实际执行的命令（见 Get-WinstDetectedVersionCore）
            if ($programText -match '(?i)\.jar$') {
                $detectLines += ('运行这个命令读取版本号: java -jar "{0}" {1}' -f $programText, $argsText)
            } else {
                $detectLines += ('运行这个命令读取版本号: {0} {1}' -f $programText, $argsText)
            }
        }
        default { $detectLines += '不做版本检测' }
    }
    Write-ResolvedStage -Marker '⑥' -Label '检测' -Lines $detectLines
}
