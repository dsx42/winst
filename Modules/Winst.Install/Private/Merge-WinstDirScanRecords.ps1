#Requires -Version 5.1

function Merge-WinstDirScanRecords {
    <#
    .SYNOPSIS
        ④ 目录登记：清单里有对应 id 的按清单 detect 识别版本；清单里没有的按目录登记。
    #>
    param([hashtable]$Context, $DirRecords, $Found, [switch]$VerboseOutput)

    foreach ($record in @($DirRecords)) {
        $matchId = [string]$record['MatchId']
        if ($matchId) {
            if ($Found.Contains($matchId)) { continue }   # 已由注册表识别（installer 以注册表的安装位置为准）
            $app = $record['App']
            $type = (Get-EntryString -Entry $app -Key 'type').Trim().ToLowerInvariant()
            $detect = Get-WinstDetectedVersion -Context $Context -Plan $app -InstallDir ([string]$record['FullName']) -SourceName ([string]$record['Source'])
            $version = 'unknown'
            if ($detect.Ok -and $detect.Version) { $version = [string]$detect.Version }
            $Found[$matchId] = New-WinstScanRecord -Id $matchId -Version $version -Type $type `
                -InstallDir ([string]$record['FullName']) -Managed 'winst' -Source ([string]$record['Source'])
            if ($VerboseOutput) {
                $detail = ''
                if ($detect.Detail) { $detail = ('（{0}）' -f [string]$detect.Detail) }
                Write-Host ('    [目录] {0} → 版本 {1}{2}' -f $matchId, $version, $detail) -ForegroundColor DarkGray
            }
            continue
        }

        # 清单里没有对应软件：仍按目录登记，保证 installRoot 下的文件夹都能在安装记录里看到
        $dirId = [string]$record['DirName']
        if (-not $dirId -or $Found.Contains($dirId)) { continue }
        $Found[$dirId] = New-WinstScanRecord -Id $dirId -Managed 'winst' -DirOnly
        if ($VerboseOutput) {
            Write-Host ('    [目录] {0} → 清单里没有对应软件，按目录登记' -f $dirId) -ForegroundColor DarkGray
        }
    }
}
