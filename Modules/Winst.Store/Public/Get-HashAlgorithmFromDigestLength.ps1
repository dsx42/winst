#Requires -Version 5.1

function Get-HashAlgorithmFromDigestLength {
    <#
    .SYNOPSIS
        按摘要长度（十六进制字符数）判断校验算法；认不出来时返回空串。
    .DESCRIPTION
        清单里的 files[].hash 字面值与 hashFile 摘要有多种算法（md5 / sha1 / sha256 / sha512），
        实际比对必须用同一种算法计算文件哈希；这里按摘要长度反推算法（C# 密钥算法名）。
    #>
    param([int]$Length)

    switch ($Length) {
        32  { return 'MD5' }
        40  { return 'SHA1' }
        64  { return 'SHA256' }
        128 { return 'SHA512' }
        default { return '' }
    }
}
