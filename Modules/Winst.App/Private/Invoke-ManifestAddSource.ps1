#Requires -Version 5.1

function Invoke-ManifestAddSource {
    <#
    .SYNOPSIS
        新建一个软件源：用给定地址尝试添加，失败时说明原因并允许重新输入。
    .DESCRIPTION
        名称自动取「用户名/仓库」，不需要用户填写。添加前会实际拉取清单校验，
        校验失败（仓库不存在 / 没有 manifest.json / 清单内容非法）时写明原因且不写入。

        `-RepoOrUrl` 为空时向用户要一句；输入 `c` 从剪贴板读取（终端不支持粘贴时的退路）。
        失败后直接回车即放弃。

    .OUTPUTS
        @{ Ok = <bool>; Cancelled = <bool>; Message }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string]$RepoOrUrl = ''
    )

    $result = @{ Ok = $false; Cancelled = $false; Message = '' }

    Write-Section '新建软件源'
    Write-Host '  软件源只支持 GitHub 仓库，名称自动取「用户名/仓库」，无需填写。' -ForegroundColor DarkGray
    Write-Host '  可输入：owner/repo' -ForegroundColor DarkGray
    Write-Host '          https://github.com/owner/repo' -ForegroundColor DarkGray
    Write-Host '          https://raw.githubusercontent.com/owner/repo/main/manifest.json' -ForegroundColor DarkGray
    Write-Host '  默认从仓库根目录、默认分支读取 manifest.json；清单地址带分支/路径时按原样使用。' -ForegroundColor DarkGray
    Write-Host '  地址可直接粘贴；若终端不支持粘贴，可输入 c 从剪贴板读取。' -ForegroundColor DarkGray
    Write-Host ''

    $address = ConvertTo-WinstTrimmedInput -Value $RepoOrUrl
    if (-not $address) { $address = Read-ManifestSourceAddress }

    while ($true) {
        if (-not $address) {
            Write-Host '  已取消。' -ForegroundColor DarkGray
            $result.Cancelled = $true
            return $result
        }

        $added = Add-RemoteManifest -Context $Context -RepoOrUrl $address
        Write-Host ''
        if ($added.Success) {
            Write-Host ('  {0}' -f $added.Message) -ForegroundColor Green
            $result.Ok = $true
            $result.Message = [string]$added.Message
            return $result
        }

        $result.Message = [string]$added.Message
        Write-Host ('  {0}' -f $result.Message) -ForegroundColor Yellow
        Write-Host '  请重新输入（直接回车放弃）。' -ForegroundColor DarkGray

        $address = Read-ManifestSourceAddress -Prompt '  软件源地址（直接回车放弃）'
        Write-Host ''
    }
}
