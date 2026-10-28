#Requires -Version 5.1

function Get-HashFromChecksumFile {
    <#
    .SYNOPSIS
        从校验文件内容里取出某个安装包的摘要。
    .OUTPUTS
        @{ Ok; Hash; Error }
    .DESCRIPTION
        两种内置识别器（默认 sha256sums）：
          `sha256sums` / `sha512sums` / `sha1sums` / `md5sums` —— 官方校验文件常见格式逐行解析
              <摘要>  <文件名>（文件名可带 * 前缀、行尾可有空白），按文件名匹配（忽略大小写与路径部分）；
          `sha256` / `sha512` / `sha1` / `md5` —— 文件里只放一串摘要时用（如 Maven 的 .sha512），
              取第一个符合长度的摘要即可，不必写 re: 正则。
        `digest` 是预置的「按文件名就近取摘要」处理器：内容里文件名与摘要相邻时用（GitHub 资产列表页、
        镜像站的 ISO 列表等），算法按摘要长度判定，因此 MD5 / SHA-1 / SHA-256 / SHA-512 都支持。
        需要别的特殊格式时才写 re: 正则（命名组 h 或第 1 捕获组）。
    #>
    param([string]$Text, [string]$FileName, [string]$Rule)

    $result = @{ Ok = $false; Hash = ''; Error = '' }
    $ruleText = ''
    if ($null -ne $Rule) { $ruleText = ([string]$Rule).Trim() }
    if (-not $ruleText) { $ruleText = 'sha256sums' }

    # 预置处理器：校验内容里文件名与摘要相邻（GitHub 资产列表页、镜像站的 ISO 列表等），
    # 清单里不必再写一条 re: 正则。只在文件名之后的一小段里找，避免取到相邻条目的摘要。
    if ($ruleText -ieq 'digest') {
        $target = ([string]$FileName).Trim()
        $text = [string]$Text
        if (-not $target) {
            $result.Error = '按文件名取摘要需要文件名，但调用方没有给出'
            return $result
        }
        if (-not $text) {
            $result.Error = '校验内容为空，无法按文件名取摘要'
            return $result
        }
        $index = $text.IndexOf($target, [StringComparison]::OrdinalIgnoreCase)
        if ($index -lt 0) {
            $result.Error = ('校验内容里没有找到这个安装包的文件名（{0}）' -f $target)
            return $result
        }
        $start = $index + $target.Length
        $window = $text.Substring($start, [Math]::Min(2000, $text.Length - $start))
        # 长摘要优先：同一段十六进制不会被更短的规则先截断
        $match = [regex]::Match($window, '(?i)(?<![0-9a-f])(?:[0-9a-f]{128}|[0-9a-f]{64}|[0-9a-f]{40}|[0-9a-f]{32})(?![0-9a-f])')
        if (-not $match.Success) {
            $result.Error = ('校验内容里「{0}」后面没有可识别的摘要（32 / 40 / 64 / 128 位十六进制）' -f $target)
            return $result
        }
        $result.Hash = $match.Value.ToLowerInvariant()
        $result.Ok = $true
        return $result
    }

    if (Test-RegexRuleText -Rule $ruleText) {
        $capture = Get-RegexCaptureValue -Text $Text -Pattern (Get-RegexRuleText -Rule $ruleText) -GroupName 'h'
        if (-not $capture.Hit) {
            $result.Error = '校验文件里没有找到符合规则的摘要'
            return $result
        }
        $result.Hash = ([string]$capture.Value).Trim()
        $result.Ok = $true
        return $result
    }

    $hashRule = Get-WinstHashRule -Kind $ruleText
    if (-not $hashRule.Valid) {
        $result.Error = ('不认识的校验方式「{0}」；可用 sha256sums、sha512sums、sha1sums、md5sums（或简写 sha256 / sha512 / sha1 / md5）、digest（按文件名就近取摘要），也可用 re: 正则' -f $ruleText)
        return $result
    }
    $length = [int]$hashRule.Length
    $needsFileName = [bool]$hashRule.NeedsFileName

    $target = ''
    if ($needsFileName -and $null -ne $FileName) { $target = ([string]$FileName).Trim() }
    # 需要按文件名匹配：<摘要> <文件名>；纯摘要文件（sha512 这类）：整行就是一段摘要
    $pattern = '^\s*(?<h>[0-9a-fA-F]{' + $length + '})\s+(\*?(?<f>.+?))\s*$'

    foreach ($line in ([string]$Text -split "`r?`n")) {
        if ($needsFileName) {
            $m = [regex]::Match($line, $pattern)
            if (-not $m.Success) { continue }

            $name = $m.Groups['f'].Value.Trim().Trim('"')
            if ($name.IndexOf('/') -ge 0) { $name = $name.Substring($name.LastIndexOf('/') + 1) }
            if ($name.IndexOf('\') -ge 0) { $name = $name.Substring($name.LastIndexOf('\') + 1) }
            if ($target -and $name -ine $target) { continue }

            $result.Hash = $m.Groups['h'].Value
            $result.Ok = $true
            return $result
        }

        # 纯摘要文件：整行就是摘要（去掉空白 / 引号）；行尾跟着文件名（`<摘要>  <文件名>`）时也取得到
        $digest = ([string]$line).Trim().Trim('"')
        if ($digest -cmatch ('^[0-9a-fA-F]{' + $length + '}$')) {
            $result.Hash = $digest
            $result.Ok = $true
            return $result
        }
        $inline = [regex]::Match($digest, ('(?i)\b(?<h>[0-9a-f]{' + $length + '})\b'))
        if ($inline.Success) {
            $result.Hash = $inline.Groups['h'].Value
            $result.Ok = $true
            return $result
        }
    }

    if ($target) {
        $result.Error = ('校验文件里没有找到这个安装包的摘要（文件名 {0}）' -f $target)
    } else {
        $result.Error = '校验文件里没有找到摘要'
    }
    return $result
}
