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

    $configPath = Join-Path $DataRoot 'config.json'
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
            # 配置损坏：使用默认值，后续业务版本再补「自动备份重建」
        }
    }

    return $defaults
}
