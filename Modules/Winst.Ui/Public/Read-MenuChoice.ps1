#Requires -Version 5.1

function Read-MenuChoice {
    <#
    .SYNOPSIS
        读取并校验菜单输入；非法输入重新提示，不退出。非交互宿主中读入失败按退出处理。
    .DESCRIPTION
        非交互宿主（输入被重定向或已到 EOF）下 Read-Host 会持续返回空值，若按「非法输入」
        处理将无限重提示；此处检测到重定向或连续多次空输入即视为无法读取键盘输入并退出。
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Valid,
        [string]$Prompt = '请选择'
    )

    $emptyStreak = 0
    while ($true) {
        try {
            $raw = Read-Host $Prompt
        } catch {
            # 无控制台（输入被重定向 / 宿主不支持）：友好退出
            return 'q'
        }

        $value = ''
        if ($null -ne $raw) { $value = ([string]$raw).Trim() }

        if (-not $value) {
            $emptyStreak++
            if ((Test-WinstInputRedirected) -or $emptyStreak -ge 5) {
                Write-Host ''
                Write-Host '  未检测到键盘输入，已退出菜单。' -ForegroundColor Yellow
                return 'q'
            }
        } else {
            $emptyStreak = 0
        }

        if ($value -and ($Valid -contains $value)) {
            return $value
        }

        Write-Host '  输入无效，请重新选择。' -ForegroundColor Yellow
        Write-Host ''
    }
}
