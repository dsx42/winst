#Requires -Version 5.1
<#
    Get-WinstSelfSourceVersion.ps1  (Winst.Install / Private)

    从 winst release 包里读出产品版本，不安装任何东西。

    为什么需要它
    ------------
    `winst install winst --from <路径>` 必须在动任何一个文件之前回答
    「这个包比磁盘上的新吗」。版本只能来自包本身：
    release 资产名是固定的（winst.zip），刻意不带版本号。

    版本号在哪
    ----------
    唯一来源是 Get-WinstProductVersion 的返回值。它在包里可能出现于两处：

        开发树 / 旧包      Modules\Winst.Core\Public\WinstConstants.ps1
        release 单一模块   Modules\Winst\Winst.psm1

    两者按同一份 AST 取值，因此台账记下的版本与包运行后自报的版本完全一致。

    两种包形态
    ----------
        <路径> 是目录 : 直接读文件
        <路径> 是压缩包 : 在内存中从 zip 里读出条目，不解压、不落临时文件

    .OUTPUTS
        @{ Ok; Version; Error }
#>
function Get-WinstSelfSourceVersion {
    <#
    .SYNOPSIS
        读取 winst 包（压缩包或已解压目录）的产品版本。

    .PARAMETER Path
        release 压缩包，或结构相同的目录（winst.ps1 + Modules\）。

    .OUTPUTS
        @{ Ok; Version; Error }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    $result = @{ Ok = $false; Version = ''; Error = '' }

    # 按顺序找：先开发树布局，再单一模块布局。两处都定义了同一个函数。
    $candidates = @(
        'Modules\Winst.Core\Public\WinstConstants.ps1'
        'Modules\Winst\Winst.psm1'
    )

    try {
        if (Test-Path -LiteralPath $Path -PathType Container) {
            foreach ($relative in $candidates) {
                $candidatePath = Join-Path $Path $relative
                if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) { continue }

                $version = ConvertFrom-WinstProductVersionText -Text ([IO.File]::ReadAllText($candidatePath))
                if ($version) {
                    $result.Ok = $true
                    $result.Version = $version
                    return $result
                }
            }

            $result.Error = ('这个目录不是 winst 安装包：找不到可读的产品版本（{0}）' -f ($candidates -join ' / '))
            return $result
        }

        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            $result.Error = ('找不到 winst 安装包：{0}' -f $Path)
            return $result
        }

        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop

        $archive = [IO.Compression.ZipFile]::OpenRead($Path)
        try {
            $entries = @($archive.Entries | ForEach-Object { @{ Name = ([string]$_.FullName).Replace('\', '/'); Entry = $_ } })

            foreach ($relative in $candidates) {
                $wanted = $relative.Replace('\', '/')
                $match = $null
                foreach ($candidate in $entries) {
                    if ($candidate.Name -ieq $wanted) { $match = $candidate.Entry; break }
                }
                if (-not $match) { continue }

                $text = ''
                $stream = $match.Open()
                try {
                    $reader = New-Object IO.StreamReader($stream)
                    try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
                } finally {
                    $stream.Dispose()
                }

                $version = ConvertFrom-WinstProductVersionText -Text $text
                if ($version) {
                    $result.Ok = $true
                    $result.Version = $version
                    return $result
                }
            }
        } finally {
            $archive.Dispose()
        }

        $result.Error = ('这个压缩包不是 winst 安装包：找不到可读的产品版本（{0}）' -f ($candidates -join ' / '))
        return $result
    } catch {
        $result.Error = ('读取 winst 安装包版本失败：{0}' -f $_.Exception.Message)
        return $result
    }
}
