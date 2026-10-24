#Requires -Version 5.1

function Test-WinstProtectedDirectory {
    <#
    .SYNOPSIS
        判断路径是否是「绝不能递归删除」的系统 / 用户关键目录（盘根、Windows、System32、Program Files 等）。
    .DESCRIPTION
        递归删除前的最后一道闸：这些目录本身的删除一定是脏数据导致的（id 越界、台账被改、注册表路径被改）。
        只做「整目录」判定——`C:\Program Files\MyApp` 这类正常安装目录不受影响。
    .OUTPUTS
        [bool]
    #>
    param([string]$Path)

    if (-not $Path) { return $true }
    $full = ''
    try { $full = ([IO.Path]::GetFullPath((ConvertTo-WinstPlainDevicePath -Path ([string]$Path)))).TrimEnd('\', '/') } catch { return $true }
    if (-not $full) { return $true }
    # 剩下的设备路径（\\?\Volume{...} / \\?\GLOBALROOT\... 等）无法归一成盘符路径，也就无法证明它不在关键目录下；
    # 递归删除这类路径的风险远大于收益 → 一律按「受保护」拒绝。
    if ($full.StartsWith('\\?\', [StringComparison]::Ordinal) -or $full.StartsWith('\\.\', [StringComparison]::Ordinal)) { return $true }
    if ($full -match '^[A-Za-z]:$') { return $true }
    if ($full.Split('\').Count -lt 2) { return $true }

    $protected = @(
        '(?i)^[A-Za-z]:\\Windows$',
        '(?i)^[A-Za-z]:\\Windows\\(System32|SysWOW64|WinSxS|System|Temp|assembly|Microsoft\.NET|servicing|Fonts|INF|Boot|diagnostics|Prefetch)$',
        '(?i)^[A-Za-z]:\\Program Files( \(x86\))?$',
        '(?i)^[A-Za-z]:\\Program Files( \(x86\))?\\(Common Files|WindowsApps|Windows Defender|Windows NT|Internet Explorer|ModifiableWindowsApps)$',
        '(?i)^[A-Za-z]:\\ProgramData$',
        '(?i)^[A-Za-z]:\\ProgramData\\(Microsoft|Package Cache|Desktop|Documents)$',
        '(?i)^[A-Za-z]:\\Users$',
        '(?i)^[A-Za-z]:\\Users\\[^\\]+$',
        '(?i)^[A-Za-z]:\\Users\\[^\\]+\\(Desktop|Documents|Downloads|Pictures|Videos|Music|AppData|AppData\\(Local|Roaming|LocalLow))$',
        '(?i)^[A-Za-z]:\\\$Recycle\.Bin$',
        '(?i)^[A-Za-z]:\\System Volume Information$',
        '(?i)^[A-Za-z]:\\Recovery$',
        '(?i)^[A-Za-z]:\\PerfLogs$'
    )
    foreach ($pattern in $protected) {
        if ($full -match $pattern) { return $true }
    }
    return $false
}
