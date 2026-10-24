#Requires -Version 5.1

function Invoke-WinstUpdateCommand {
    <#
    .SYNOPSIS
        CLI：winst update [--check] [--download-only] [--force] [<id>...|--all]。
    .OUTPUTS
        [int] 退出码：0 成功 / 1 参数错误 / 2 网络失败 / 3 更新失败 / 4 仅 --check 检测到可更新项
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [string[]]$Arguments = @()
    )

    $ids = @()
    $all = $false
    $check = $false
    $downloadOnly = $false
    $force = $false
    $filesOnly = $false
    $forceSystemItems = $false
    $sourceName = ''
    $yes = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Yes)

    $usage = '  用法: winst update [--check] [--download-only] [--force] [--files-only|--system-items] [--source <名称>] [<id>...|--all]'

    for ($i = 0; $i -lt @($Arguments).Count; $i++) {
        $text = [string]$Arguments[$i]
        if ($text -eq '--all') { $all = $true }
        elseif ($text -eq '--check') { $check = $true }
        elseif ($text -eq '--download-only') { $downloadOnly = $true }
        elseif ($text -eq '--force') { $force = $true }
        elseif ($text -eq '--files-only') { $filesOnly = $true }
        elseif ($text -eq '--system-items') { $forceSystemItems = $true }
        elseif ($text -eq '--source') {
            # 值就地消费；下一个 token 是开关或已到末尾时明确报错，不静默按默认来源执行
            if ((($i + 1) -lt @($Arguments).Count) -and -not (([string]$Arguments[$i + 1]).StartsWith('-'))) {
                $sourceName = ([string]$Arguments[$i + 1]).Trim()
                $i++
            } else {
                Write-Host ''
                Write-Host '  --source 缺少取值，请写成 --source <名称> 或 --source=<名称>。' -ForegroundColor Yellow
                Write-Host $usage -ForegroundColor Gray
                return 1
            }
        }
        elseif ($text.StartsWith('--source=')) { $sourceName = ($text.Substring(9)).Trim() }
        elseif (Try-Apply-WinstCommonCliFlag -Text $text -Yes ([ref]$yes)) { }
        elseif ($text.StartsWith('-')) {
            Write-Host ''
            Write-Host ('  未知参数: {0}' -f $text) -ForegroundColor Yellow
            Write-Host $usage -ForegroundColor Gray
            return 1
        } else {
            if ($ids -notcontains $text) { $ids += $text }
        }
    }

    if ($check -and $downloadOnly) {
        Write-Host ''
        Write-Host '  参数冲突: --check 只检查不执行，不能与 --download-only 同时使用。' -ForegroundColor Yellow
        Write-Host $usage -ForegroundColor Gray
        return 1
    }
    if ($all -and $ids.Count -gt 0) {
        Write-Host ''
        Write-Host '  参数冲突: --all 与具体软件 id 不能同时使用。' -ForegroundColor Yellow
        Write-Host $usage -ForegroundColor Gray
        return 1
    }
    if ($all -and $sourceName) {
        Write-Host ''
        Write-Host '  参数冲突: --source 只对指定 id 的更新生效，不能与 --all 同时使用。' -ForegroundColor Yellow
        Write-Host $usage -ForegroundColor Gray
        return 1
    }

    Write-Section 'update'
    if ($filesOnly) {
        Write-Host '  仅更新文件：不处理环境变量 / PATH / 快捷方式（保留现有设置）' -ForegroundColor DarkYellow
    } elseif ($forceSystemItems) {
        Write-Host '  完整更新：按软件源里的定义写入 / 覆盖环境变量、PATH 项与快捷方式' -ForegroundColor DarkYellow
    } else {
        Write-Host ('  更新方式: {0}' -f (Format-UpdateFilesOnlyDisplay -Value (Get-ConfigValue -Config $Context.Config -Key 'updateFilesOnly' -Default $true))) -ForegroundColor DarkGray
    }

    $result = Invoke-WinstUpdateTargets -Context $Context -Ids $ids -All:$all -Check:$check `
        -DownloadOnly:$downloadOnly -Force:$force -Yes:$yes -FilesOnly:$filesOnly -ForceSystemItems:$forceSystemItems -SourceName $sourceName
    return [int]$result.ExitCode
}
