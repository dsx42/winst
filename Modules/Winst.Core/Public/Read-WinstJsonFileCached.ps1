#Requires -Version 5.1

function Read-WinstJsonFileCached {
    <#
    .SYNOPSIS
        读取并解析 JSON 文件，结果按 (路径, 时间戳, 长度) 在进程内缓存。
    .DESCRIPTION
        清单 / 解析锁 / 缓存索引 / 状态文件在一次操作里会被反复读（按 id 查、按源查、每条新鲜度提示各读一次），
        每次都 Get-Content + ConvertFrom-Json 是主要开销。这里只缓存**解析结果**，每次返回新的包装哈希表；
        但 Value 是缓存里的同一个对象，调用方**不得就地修改**，需要改时先复制（Copy-WinstObjectShallow）。
        修改文件会让时间戳变化、缓存自动失效。
    .OUTPUTS
        @{ Ok; Value; Raw; Error }
    #>
    param([Parameter(Mandatory = $true)][string]$Path)

    $result = @{ Ok = $false; Value = $null; Raw = ''; Error = '' }
    $stamp = Get-WinstFileStamp -Path $Path
    if (-not $stamp) {
        $result.Error = '文件不存在'
        return $result
    }

    $cached = (Get-WinstState -Name WinstJsonCache)[$Path]
    if ($cached -and ([string]$cached['Stamp'] -eq $stamp)) {
        $result.Ok = $true
        $result.Value = $cached['Value']
        $result.Raw = [string]$cached['Raw']
        return $result
    }

    $raw = ''
    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    } catch {
        $result.Error = $_.Exception.Message
        return $result
    }

    if (-not $raw -or -not $raw.Trim()) {
        (Get-WinstState -Name WinstJsonCache)[$Path] = @{ Stamp = $stamp; Value = $null; Raw = '' }
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

    (Get-WinstState -Name WinstJsonCache)[$Path] = @{ Stamp = $stamp; Value = $obj; Raw = [string]$raw }
    $result.Ok = $true
    $result.Value = $obj
    $result.Raw = [string]$raw
    return $result
}
