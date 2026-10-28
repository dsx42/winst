#Requires -Version 5.1

function Get-WinstHashRule {
    <#
    .SYNOPSIS
        把 hashFrom 关键字解析成校验规则（摘要长度 / 是否按文件名匹配 / 算法名 / 展示名）。
    .DESCRIPTION
        两种写法等价：`sha256sums` 这类识别器按「<摘要>  <文件名>」逐行匹配文件名；
        `sha256` 这类短写法用于**只含一串摘要**的校验文件（如 Maven 的 .sha512），
        直接取文件里的第一段摘要，不必写 re: 正则。

        **这是这张表的唯一定义处**：摘要长度、是否按文件名、C# 算法名、展示名都从这里取，
        调用方不各自 switch 一遍。
        未知关键字返回 Valid = $false，由调用方决定错误文案。
    .OUTPUTS
        @{ Valid; Key; Length; NeedsFileName; Algorithm; Display }
    #>
    param([string]$Kind)

    $k = ''
    if ($Kind) { $k = ([string]$Kind).Trim().ToLowerInvariant() }

    $table = @{
        'md5sums'    = @{ Length = 32;  NeedsFileName = $true;  Algorithm = 'MD5';    Display = 'md5' }
        'sha1sums'   = @{ Length = 40;  NeedsFileName = $true;  Algorithm = 'SHA1';   Display = 'sha1' }
        'sha256sums' = @{ Length = 64;  NeedsFileName = $true;  Algorithm = 'SHA256'; Display = 'sha256' }
        'sha512sums' = @{ Length = 128; NeedsFileName = $true;  Algorithm = 'SHA512'; Display = 'sha512' }
        'md5'        = @{ Length = 32;  NeedsFileName = $false; Algorithm = 'MD5';    Display = 'md5' }
        'sha1'       = @{ Length = 40;  NeedsFileName = $false; Algorithm = 'SHA1';   Display = 'sha1' }
        'sha256'     = @{ Length = 64;  NeedsFileName = $false; Algorithm = 'SHA256'; Display = 'sha256' }
        'sha512'     = @{ Length = 128; NeedsFileName = $false; Algorithm = 'SHA512'; Display = 'sha512' }
        # digest：按文件名就近取摘要，摘要长度由内容决定（32 / 40 / 64 / 128），所以 Length = 0
        'digest'     = @{ Length = 0;   NeedsFileName = $true;  Algorithm = '';       Display = '摘要' }
    }
    if (-not $table.ContainsKey($k)) {
        return @{ Valid = $false; Key = $k; Length = 0; NeedsFileName = $false; Algorithm = ''; Display = '' }
    }
    $row = $table[$k]
    return @{
        Valid         = $true
        Key           = $k
        Length        = [int]$row.Length
        NeedsFileName = [bool]$row.NeedsFileName
        Algorithm     = [string]$row.Algorithm
        Display       = [string]$row.Display
    }
}
