#Requires -Version 5.1

function Get-Winst7zSfxPayload {
    <#
    .SYNOPSIS
        从 7-Zip 自解压安装包（.exe）里取出内嵌的 7z 载荷，另存为独立的 .7z 文件。
    .DESCRIPTION
        官方 7-Zip 的 `7z<版本>-x64.exe` 是「PE 外壳 + 内嵌 7z 档案」的自解压包。它自己就是
        安装程序，直接运行会写注册表、覆盖本机已装的 7-Zip；要给 7-Zip-CLI 用的只是其中的
        7z.exe / 7z.dll，因此必须当压缩包解开、而不是执行。

        载荷位置按 PE 结构算出，不扫描内容：内嵌 7z 紧接在最后一个节的原始数据之后
        （覆盖区起点 = max(SizeOfHeaders, 各节 PointerToRawData + SizeOfRawData)）。外壳的资源段里
        也会出现同样的签名，按结构定位不会误判，也不需要把整个安装包读进内存。

        校验：覆盖区起点必须是 7z 签名 `37 7A BC AF 27 1C`；随后读 Start Header 的
        NextHeaderOffset / NextHeaderSize，要求 `32 + offset + size` 正好等于文件长度，
        且 NextHeader 首字节是 0x01（未压缩头）或 0x17（编码头）。

        调用方传 `-AllowSfxPayload` 时才会进这一档：只有安装 7-Zip-CLI 的引导流程会传
        （见 Expand-WinstPackageArchive）。
    .OUTPUTS
        @{ Ok; Path; Offset; Error }
        Ok = $true 时 Path 是临时 .7z 文件（调用方负责删除）；不是这种自解压包时 Ok = $false
        且 Error 为空，调用方按「普通压缩包」继续即可。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$DestDir
    )

    $result = @{ Ok = $false; Path = ''; Offset = -1; Error = '' }

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $result.Error = ('找不到文件：{0}' -f $Path)
        return $result
    }

    $stream = $null
    try {
        $stream = [IO.File]::OpenRead($Path)
        $length = $stream.Length
        if ($length -lt 128) { return $result }

        # PE 头 + 节表：真实 PE 不会超过几 KB，读一段就够
        $head = New-Object byte[] 8192
        $headLength = $stream.Read($head, 0, $head.Length)
        if ($headLength -lt 64) { return $result }
        if (-not ($head[0] -eq 0x4D -and $head[1] -eq 0x5A)) { return $result }

        $peOffset = [BitConverter]::ToInt32($head, 0x3C)
        if ($peOffset -lt 0 -or ($peOffset + 24) -gt $headLength) { return $result }
        $sectionCount = [BitConverter]::ToUInt16($head, $peOffset + 6)
        $optionalSize = [BitConverter]::ToUInt16($head, $peOffset + 20)
        $sizeOfHeaders = [BitConverter]::ToUInt32($head, $peOffset + 24 + 60)
        $sectionStart = $peOffset + 24 + $optionalSize

        $overlay = [int64]$sizeOfHeaders
        for ($i = 0; $i -lt $sectionCount; $i++) {
            $sectionOffset = $sectionStart + ($i * 40)
            if (($sectionOffset + 24) -gt $headLength) { return $result }
            $rawSize = [BitConverter]::ToUInt32($head, $sectionOffset + 16)
            $rawPointer = [BitConverter]::ToUInt32($head, $sectionOffset + 20)
            $sectionEnd = [int64]$rawPointer + [int64]$rawSize
            if ($sectionEnd -gt $overlay) { $overlay = $sectionEnd }
        }
        if ($overlay -lt 0 -or ($overlay + 32) -gt $length) { return $result }

        $startHeader = New-Object byte[] 32
        $stream.Position = $overlay
        if ($stream.Read($startHeader, 0, 32) -ne 32) { return $result }

        $signature = [byte[]](0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C)
        for ($i = 0; $i -lt $signature.Length; $i++) {
            if ($startHeader[$i] -ne $signature[$i]) { return $result }
        }

        # Start Header：签名(6) + 版本(2) + StartHeaderCRC(4) + NextHeaderOffset(8) + NextHeaderSize(8) + NextHeaderCRC(4)
        $nextOffset = [BitConverter]::ToUInt64($startHeader, 12)
        $nextSize = [BitConverter]::ToUInt64($startHeader, 20)
        # UInt64 → Int64 溢出会抛异常（StrictMode 下是终止错误）：先用文件长度挡掉不可能的取值
        if ($nextOffset -gt [uint64]$length -or $nextSize -gt [uint64]$length) { return $result }
        # 结构自校验：载荷是文件的最后一段，末尾正好对齐
        if (($overlay + 32 + [int64]$nextOffset + [int64]$nextSize) -ne $length) { return $result }

        $stream.Position = $overlay + 32 + [int64]$nextOffset
        $headerByte = $stream.ReadByte()
        # 0x01 = kHeader（未压缩头），0x17 = kEncodedHeader（压缩过的头），两者都是合法 7z 头
        if ($headerByte -ne 0x01 -and $headerByte -ne 0x17) { return $result }

        if ($DestDir -and -not (Test-Path -LiteralPath $DestDir -PathType Container)) {
            $null = New-Item -ItemType Directory -Path $DestDir -Force -ErrorAction Stop
        }
        $target = Join-WinstPath $DestDir ('sfx-payload-' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.7z')
        $stream.Position = $overlay
        $output = [IO.File]::Create($target)
        try {
            $stream.CopyTo($output)
        } finally {
            $output.Dispose()
        }

        $result.Path = $target
        $result.Offset = $overlay
        $result.Ok = $true
    } catch {
        $result.Error = ('切出 7-Zip 载荷失败：{0}' -f $_.Exception.Message)
    } finally {
        if ($stream) { $stream.Dispose() }
    }

    return $result
}
