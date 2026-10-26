#Requires -Version 5.1

function Get-Winst7zSfxPayload {
    <#
    .SYNOPSIS
        从 7-Zip 自解压安装包（.exe）里取出内嵌的 7z 载荷，另存为独立的 .7z 文件。

    .DESCRIPTION
        官方 7-Zip 的 `7z<版本>-x64.exe` 是「PE 外壳 + 内嵌 7z 档案」的自解压包。它自己就是
        安装程序，直接运行会真的去写注册表、装到 Program Files；要给 7-Zip-CLI 用的只是其中的
        7z.exe / 7z.dll，因此必须当压缩包解开、而不是执行。

        为什么要自己切：系统自带的 `tar.exe`（bsdtar / libarchive）认 7-Zip SFX，但**扫描窗口有
        版本差异**——libarchive 3.6 及以前只在 `0x27000`～`0x60000` 之间找 7z 签名
        （`SFX_MIN_ADDR` / `SFX_MAX_ADDR`），而 7-Zip 26.x 的载荷起点已经前移到约 `0xB200`
        （45 KB 左右，落在窗口下界之下），于是旧版 bsdtar 直接报「无法识别的归档格式」。
        Windows 10 21H2 自带的就是这类旧版 libarchive；Windows 11 24H2 自带 3.8+ 才改成按 PE
        节表定位，因此同样的包在新系统上能解、在老系统上不能——这不是包坏了，是系统工具太旧。

        本函数按 7z 规范的头结构自己找载荷，不依赖任何外部工具：
          1. 在文件里找 7z 签名 `37 7A BC AF 27 1C` 的候选位置（可能有多处，外壳代码里也会出现）；
          2. 读签名后的 Start Header：NextHeaderOffset / NextHeaderSize，
             要求 `32 + offset + size` **正好等于文件长度**——只有真正的载荷末尾才对得上，
             这是区分真载荷与偶然出现的签名的关键；
          3. 校验 NextHeader 处第一个字节是 0x01（未压缩头）或 0x17（编码头）；
          4. 全部通过才把「签名起始位置到文件末尾」切出来写成 .7z。

        切出来的文件是标准 7z 档案，任何版本的 7-Zip / bsdtar / Expand-Archive 外层都能接手。

    .OUTPUTS
        @{ Ok; Path; Offset; Error }
        Ok = $true 时 Path 是临时 .7z 文件（调用方负责删除）；不是 SFX 包或结构校验失败时
        Ok = $false 且 Error 说明原因（不是 SFX 时 Error 为空，调用方按「普通压缩包」继续即可）。
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

    $bytes = $null
    try {
        $bytes = [IO.File]::ReadAllBytes($Path)
    } catch {
        $result.Error = ('读取文件失败：{0}' -f $_.Exception.Message)
        return $result
    }
    if ($bytes.Length -lt 64) { return $result }

    # 只处理 PE（MZ）外壳；其它文件不是自解压包，交给调用方按普通压缩包处理
    if (-not ($bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A)) { return $result }

    $signature = [byte[]](0x37, 0x7A, 0xBC, 0xAF, 0x27, 0x1C)
    $total = $bytes.Length

    for ($offset = 0; $offset -le $total - 32; $offset++) {
        if ($bytes[$offset] -ne $signature[0]) { continue }

        $hit = $true
        for ($i = 1; $i -lt $signature.Length; $i++) {
            if ($bytes[$offset + $i] -ne $signature[$i]) { $hit = $false; break }
        }
        if (-not $hit) { continue }

        # Start Header：签名(6) + 版本(2) + StartHeaderCRC(4) + NextHeaderOffset(8) + NextHeaderSize(8) + NextHeaderCRC(4)
        $nextOffset = [BitConverter]::ToUInt64($bytes, $offset + 12)
        $nextSize = [BitConverter]::ToUInt64($bytes, $offset + 20)

        # 结构自校验：载荷必须是「文件的最后一段」，末尾正好对齐——
        # 外壳代码里偶然出现的同字节序列不会满足这一条
        $declaredEnd = [int64]$offset + 32 + [int64]$nextOffset + [int64]$nextSize
        if ($declaredEnd -ne [int64]$total) { continue }

        $headerPos = $offset + 32 + [int64]$nextOffset
        if ($headerPos -lt 0 -or $headerPos -ge $total) { continue }
        $headerByte = $bytes[$headerPos]
        # 0x01 = kHeader（未压缩头），0x17 = kEncodedHeader（压缩过的头），两者都是合法 7z 头
        if ($headerByte -ne 0x01 -and $headerByte -ne 0x17) { continue }

        $result.Offset = $offset
        break
    }

    if ($result.Offset -lt 0) { return $result }

    try {
        if ($DestDir -and -not (Test-Path -LiteralPath $DestDir -PathType Container)) {
            $null = New-Item -ItemType Directory -Path $DestDir -Force -ErrorAction Stop
        }
        $target = Join-WinstPath $DestDir ('sfx-payload-' + [Guid]::NewGuid().ToString('N').Substring(0, 8) + '.7z')
        $payloadLength = $total - $result.Offset
        $stream = [IO.File]::Create($target)
        try {
            $stream.Write($bytes, $result.Offset, $payloadLength)
        } finally {
            $stream.Dispose()
        }
        $result.Path = $target
        $result.Ok = $true
    } catch {
        $result.Error = ('切出 7-Zip 载荷失败：{0}' -f $_.Exception.Message)
    }

    return $result
}
