#Requires -Version 5.1

function Read-WinstJsonFileCached {
    <#
    .SYNOPSIS
        读取并解析 JSON 文件，结果按 (路径, 时间戳, 长度) 在进程内缓存。
    .DESCRIPTION
        配置、清单和清单元数据复用解析结果。每次返回新的包装哈希表，
        Value 与缓存共享，调用方修改前须复制相应数据。
        修改文件会让时间戳变化、缓存自动失效。
    .OUTPUTS
        @{ Ok; Value; Empty; Error }
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    $result = @{ Ok = $false; Value = $null; Empty = $false; Error = '' }
    $stamp = Get-WinstFileStamp -Path $Path
    if (-not $stamp) {
        $result.Error = '文件不存在'
        return $result
    }

    $cached = (Get-WinstState -Name WinstJsonCache)[$Path]
    if ($cached -and ([string]$cached['Stamp'] -eq $stamp)) {
        $result.Ok = $true
        $result.Value = $cached['Value']
        $result.Empty = [bool]$cached['Empty']
        return $result
    }

    try {
        $raw = (New-Object Text.UTF8Encoding($false, $true)).GetString([IO.File]::ReadAllBytes($Path))
        if ($raw.StartsWith([string][char]0xFEFF, [StringComparison]::Ordinal)) { $raw = $raw.Substring(1) }
    } catch {
        $result.Error = $_.Exception.Message
        return $result
    }

    if (-not $raw -or -not $raw.Trim()) {
        (Get-WinstState -Name WinstJsonCache)[$Path] = @{ Stamp = $stamp; Value = $null; Empty = $true }
        $result.Empty = $true
        $result.Ok = $true
        return $result
    }

    try {
        $obj = $raw | ConvertFrom-Json
    } catch {
        # 解析失败不缓存：文件可能正在被写入，下一次读要能立刻看到完整内容
        $result.Error = $_.Exception.Message
        return $result
    }

    (Get-WinstState -Name WinstJsonCache)[$Path] = @{ Stamp = $stamp; Value = $obj; Empty = $false }
    $result.Ok = $true
    $result.Value = $obj
    return $result
}
