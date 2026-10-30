#Requires -Version 5.1

function Write-WinstPlanHeader {
    <#
    .SYNOPSIS
        软件清单头部：标题 / 类型 / 版本 / 说明 / 已装版本 / 来源 / 依赖。
    #>
    param($Plan, [hashtable]$View, [hashtable]$Context = $null)

    Write-Host ''
    Write-Host ('  ' + ('─' * 66)) -ForegroundColor DarkGray
    Write-Host ('  {0}{1}  ({2})' -f $View.Position, $View.DisplayName, $View.Id) -NoNewline -ForegroundColor White
    if ($View.Ok) {
        Write-Host '   清单正常' -ForegroundColor Green
    } else {
        Write-Host '   清单有误' -ForegroundColor Red
    }

    $versionLineText = $View.VersionText
    if ($View.VersionNeedsConfirm -and $View.Version) { $versionLineText = ('{0}（取包后确认）' -f $View.Version) }
    Write-Host ('    类型: {0}    版本: {1}' -f (Get-PlanTypeText -Type $View.Type), $versionLineText) -ForegroundColor Gray

    $description = Get-EntryString -Entry $Plan -Key 'description'
    if ($description) {
        Write-Host ('    说明: {0}' -f $description) -ForegroundColor DarkGray
    }

    # 已装版本与更新提示；同时给出当前装在哪
    if ($View.InstalledVersion) {
        if ($View.VersionNeedsConfirm -and $View.Version) {
            # 远端有新包 / 没比出结论：目标版本要等重新取包才知道，别把缓存里那份写成「将更新到」
            Write-Host ('    ↑ 本机已安装 {0}，将重新取包核对版本（缓存里的包是 {1}，取自包内文件信息）' -f $View.InstalledVersion, $View.Version) -ForegroundColor DarkYellow
        } elseif ($View.Version -and (Compare-WinstVersion -A $View.Version -B $View.InstalledVersion) -gt 0) {
            Write-Host ('    ↑ 本机已安装 {0}，将更新到 {1}' -f $View.InstalledVersion, $View.VersionText) -ForegroundColor Green
        } else {
            Write-Host ('    本机已安装: {0}' -f $View.InstalledVersion) -ForegroundColor DarkGray
        }
        if ($View.InstalledDir) {
            Write-Host ('    安装路径: {0}' -f $View.InstalledDir) -ForegroundColor DarkGray
        }
    }

    $download = Get-EntryValue -Entry $Plan -Key 'download' -Default $null
    $sourceText = Get-PlanSourceKindText -Kind (Get-EntryString -Entry $download -Key 'kind')
    $repo = Get-EntryString -Entry $download -Key 'repo'
    $tag = Get-EntryString -Entry $download -Key 'tag'
    if ($repo) {
        $sourceText += ('（{0}' -f $repo)
        if ($tag) { $sourceText += ('，本次发布 {0}' -f $tag) }
        $sourceText += '）'
    }
    if ($View.SourceName) { $sourceText += ('    来自软件源: {0}' -f $View.SourceName) }
    Write-Host ('    来源: {0}' -f $sourceText) -ForegroundColor DarkGray

    # 依赖（条目的 dependencies）：软件源里配置了几个就列几个（含传递依赖），每项给出软件名、
    # 是否已安装、已安装版本、能否更新与更新后的版本——与安装 / 更新时「将一并处理」同源；
    # 清单有误（$ok = $false）时也照常展示，方便看到依赖配置本身
    if ($Context) {
        $dependencyLines = @(Get-WinstDependencyLines -Context $Context -Id $View.Id -Type $View.Type -Plan $Plan)
        if ($dependencyLines.Count -gt 0) {
            Write-Host '    依赖:' -ForegroundColor Gray
            foreach ($one in $dependencyLines) {
                Write-Host ('      - {0}' -f [string]$one['Text']) -ForegroundColor ([string]$one['Color'])
            }
        }
    }
}
