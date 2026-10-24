#Requires -Version 5.1

function Get-WinstDetectedVersion {
    <#
    .SYNOPSIS
        按条目的 detect 规则检测已装版本。
    .DESCRIPTION
        检测出的是程序自报版本（如 java -version 的 1.8.0_504-b01）；条目若声明了 detect.versionRewrite
        ，结果按这组
        规则统一写法后再返回——这样「台账版本 / 界面展示 / 与软件源版本的比较」三者始终是同一套写法。
    .OUTPUTS
        @{ Ok; Found; Version; Method; Detail; Note }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)]$Plan,
        [string]$InstallDir = '',
        [string]$SourceName = '',
        [string]$PkgDirForCli = ''
    )

    $result = Get-WinstDetectedVersionCore -Context $Context -Plan $Plan -InstallDir $InstallDir `
        -SourceName $SourceName -PkgDirForCli $PkgDirForCli

    if ($result.Ok -and $result.Version) {
        # 检测侧写法归一：规则来自 detect.versionRewrite（解析锁里已编译进 detect 块）
        $planDetect = Get-EntryValue -Entry $Plan -Key 'detect' -Default $null
        $rules = @(Get-EntryArray -Entry $planDetect -Key 'versionRewrite')
        if ($rules.Count -gt 0) {
            $rewritten = Get-WinstRewrittenVersion -Version ([string]$result.Version) -Rules $rules
            if ($rewritten) { $result.Version = $rewritten }
        }
    }
    return $result
}
