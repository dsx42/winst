#Requires -Version 5.1

function Get-WinstInstallDirRecords {
    <#
    .SYNOPSIS
        ② 扫描 installRoot 下的全部子目录，记录「目录名 / 完整路径 / 匹配到的清单 id」。
    .OUTPUTS
        @( [ordered]@{ DirName; FullName; MatchId; App; Source } )
    #>
    param([hashtable]$Context, $Plan, $Source, $CiId, [switch]$Quiet)

    $dirRecords = @()
    if (-not (Test-Path -LiteralPath $Context.InstallRoot -PathType Container)) {
        Write-Host ('  安装目录不存在，已跳过目录扫描: {0}' -f $Context.InstallRoot) -ForegroundColor DarkGray
        return $dirRecords
    }

    if (-not $Quiet) { Write-Host ('  正在扫描安装目录 {0} …' -f $Context.InstallRoot) -ForegroundColor Gray }
    foreach ($dir in @(Get-ChildItem -LiteralPath $Context.InstallRoot -Directory -ErrorAction SilentlyContinue)) {
        $dirId = $dir.Name
        # 台账键用清单里的 id（大小写敏感）；Windows 目录名大小写不敏感，
        # 故先按原样精确匹配，未命中再按不区分大小写兜底（取清单 id，落位用实际目录路径）。
        $matchId = ''
        if ($Plan.Contains($dirId)) {
            $matchId = $dirId
        } elseif ($CiId.ContainsKey($dirId)) {
            $matchId = [string]$CiId[$dirId]
        }
        $app = $null
        $source = ''
        if ($matchId) {
            $app = $Plan[$matchId]
            $source = [string]$Source[$matchId]
        }
        $dirRecords += [ordered]@{
            DirName  = $dirId
            FullName = $dir.FullName
            MatchId  = $matchId
            App      = $app
            Source   = $source
        }
    }
    return $dirRecords
}
