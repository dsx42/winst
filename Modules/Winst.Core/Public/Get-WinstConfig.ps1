#Requires -Version 5.1

function Get-WinstConfig {
    <#
    .SYNOPSIS
        读取 config.json；文件缺失或解析失败时返回默认值，不阻断菜单运行。
    #>
    param(
        [string]$DataRoot
    )

    $defaults = Get-WinstConfigDefaults -DataRoot $DataRoot

    $configPath = Join-WinstPath $DataRoot 'config.json'
    if (Test-Path -LiteralPath $configPath -PathType Leaf) {
        try {
            $raw = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
            if ($raw -and $raw.Trim()) {
                $obj = $raw | ConvertFrom-Json
                foreach ($key in @($defaults.Keys)) {
                    $prop = $obj.PSObject.Properties[$key]
                    if ($prop -and $null -ne $prop.Value) {
                        $defaults[$key] = $prop.Value
                    }
                }
                # 布尔项宽容归一：手写配置里的「开 / 关」「true / false」等都还原成布尔值，
                # 避免「关」被当成非空字符串而在业务判断里变成开启（见 Convert-WinstBoolText）。
                foreach ($boolKey in @('pruneOldPackages', 'updateFilesOnly')) {
                    $parsedBool = Convert-WinstBoolText -Value $defaults[$boolKey]
                    if ($null -ne $parsedBool) { $defaults[$boolKey] = $parsedBool }
                }
            }
        } catch {
            # 配置损坏：先备份原文，再按默认值运行。
            # 不静默退回默认值——用户手写的配置失效却查不到原因，比报错更难排查。
            # 同一份坏文件只留一份 .bak（与 Read-WinstState 的备份口径一致），避免每次读都生成新文件。
            $backupPath = $configPath + '.bak'
            $backupOk = $false
            try {
                $needCopy = -not (Test-Path -LiteralPath $backupPath -PathType Leaf)
                if (-not $needCopy) {
                    $needCopy = (Get-Item -LiteralPath $backupPath).LastWriteTimeUtc -lt (Get-Item -LiteralPath $configPath).LastWriteTimeUtc
                }
                if ($needCopy) { Copy-Item -LiteralPath $configPath -Destination $backupPath -Force -ErrorAction Stop }
                $backupOk = $true
            } catch { $backupOk = $false }

            # 注意用值判断而不是 Test-WinstState：后者只表示「键存在」，而初始化已经建过这个键
            if (-not (Get-WinstState -Name 'WinstConfigCorruptReported')) {
                $null = Set-WinstState -Name 'WinstConfigCorruptReported' -Value $true
                if ($backupOk) {
                    Write-Host ('  提示: 配置文件无法解析，本次按默认配置运行；原文件已备份为 {0}。' -f (Split-Path -Leaf $backupPath)) -ForegroundColor Yellow
                } else {
                    Write-Host ('  提示: 配置文件无法解析，本次按默认配置运行；备份原文件失败，原文件保持不动: {0}' -f $configPath) -ForegroundColor Yellow
                }
            }
        }
    }

    return $defaults
}
