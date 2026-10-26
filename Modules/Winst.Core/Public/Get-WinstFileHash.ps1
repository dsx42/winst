#Requires -Version 5.1

function Get-WinstFileHash {
    <#
    .SYNOPSIS
        计算文件摘要，返回大写十六进制字符串；文件读不到时返回空串。

    .DESCRIPTION
        直接用 .NET 的 `SHA256` / `SHA512` / `MD5` / `SHA1` 实现，**不用 `Get-FileHash`**。

        为什么不用 `Get-FileHash`：它属于 `Microsoft.PowerShell.Utility`，靠 `PSModulePath`
        自动加载。winst 由 **PowerShell 7 会话**启动时（`winst.cmd` 从 pwsh 里跑、双击继承
        PWSH 的模块路径等），子进程 5.1 继承到的是 PowerShell 7 的 `PSModulePath`，其中
        `Microsoft.PowerShell.Utility` 是只适用于 Core 的版本，Desktop 侧自动加载失败，
        于是 `Get-FileHash` 变成「无法识别的命令」——所有校验（下载后校验、winst 自更新、
        缓存命中判定）随之失败，而报错文案是「无法将 Get-FileHash 项识别为 cmdlet」，
        与真正的校验失败难以区分。用 .NET API 就没有这层依赖。

    .PARAMETER Path
        要计算摘要的文件。

    .PARAMETER Algorithm
        `SHA256`（默认）/ `SHA512` / `SHA1` / `MD5`，大小写不敏感。

    .OUTPUTS
        [string] 大写十六进制摘要；文件不存在 / 读取失败 / 算法不支持时为空串
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$Algorithm = 'SHA256'
    )

    $name = ([string]$Algorithm).Trim().ToUpperInvariant()
    $hash = $null
    switch ($name) {
        'SHA256' { $hash = [Security.Cryptography.SHA256]::Create() }
        'SHA512' { $hash = [Security.Cryptography.SHA512]::Create() }
        'SHA1'   { $hash = [Security.Cryptography.SHA1]::Create() }
        'MD5'    { $hash = [Security.Cryptography.MD5]::Create() }
        default  { return '' }
    }

    $stream = $null
    try {
        # FileShare.ReadWrite：缓存索引 / 台账判哈希时，别的进程可能正开着同一个文件
        $stream = New-Object System.IO.FileStream(
            $Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $bytes = $hash.ComputeHash($stream)
        $builder = New-Object System.Text.StringBuilder
        foreach ($b in $bytes) { $null = $builder.Append($b.ToString('X2')) }
        return $builder.ToString()
    } catch {
        return ''
    } finally {
        if ($stream) { $stream.Dispose() }
        $hash.Dispose()
    }
}
