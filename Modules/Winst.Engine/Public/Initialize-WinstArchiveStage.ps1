#Requires -Version 5.1

function Initialize-WinstArchiveStage {
    <#
    .SYNOPSIS
        在本次实例锁对应的 Temp 内检查恢复标记、删除普通暂存残留并创建空暂存目录。
    #>
    param([Parameter(Mandatory = $true)][string]$DestDir, [string]$InputPath)

    $parent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $instanceLock = Get-WinstState -Name WinstInstanceLock
    if ($null -eq $instanceLock) { throw '尚未持有实例锁，无法使用固定暂存目录' }
    if ($parent.TrimEnd('\', '/') -ine $instanceLock.TempRoot.TrimEnd('\', '/')) {
        throw '运行期间 Temp 已改变，与持有的暂存锁不一致，请重新启动 winst'
    }
    $stage = Join-WinstPath $parent '.winst-stage'
    Assert-WinstStageRecoveryClear -TempDir $parent
    Assert-WinstSafeWritePath -Path $DestDir -Directory
    Assert-WinstSafeWritePath -Path $stage -Directory
    if ((Test-WinstPathUnderRoot -Path $DestDir -Root $stage -AllowEqual) -or
        (Test-WinstPathUnderRoot -Path $stage -Root $DestDir)) {
        throw '解压暂存目录与安装目录必须互不重叠'
    }
    if ($InputPath -and ((Test-WinstPathUnderRoot -Path $InputPath -Root $stage -AllowEqual) -or
        (Test-WinstPathUnderRoot -Path $stage -Root $InputPath))) {
        throw '输入来源与专用暂存目录 .winst-stage 必须互不重叠'
    }
    if (Test-WinstFileSystemPath -Path $stage) {
        Invoke-WinstFileStep -Name '清理上次暂存' -Action {
            Remove-WinstDirectoryTree -Path $stage
        }
    }
    $null = [IO.Directory]::CreateDirectory((ConvertTo-WinstExtendedPath -Path $stage))
    return $stage
}
