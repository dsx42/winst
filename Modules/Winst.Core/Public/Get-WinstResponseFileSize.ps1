#Requires -Version 5.1

function Get-WinstResponseFileSize {
    <#
    .SYNOPSIS
        从 HTTP 成功响应读取完整文件长度。分段传输只采用有效 Content-Range 中的总长度。
    #>
    param([int]$StatusCode, [string]$ContentLength = '', [string]$ContentRange = '')

    $bytes = 0L
    if ($StatusCode -eq 206 -or $ContentRange) {
        if ($StatusCode -notin @(200, 206) -or $ContentRange.Trim() -notmatch '\Abytes ([0-9]+)-([0-9]+)/([0-9]+)\z') { return }
        $start = 0L
        $end = 0L
        if ([long]::TryParse($Matches[1], [ref]$start) -and [long]::TryParse($Matches[2], [ref]$end) -and
                [long]::TryParse($Matches[3], [ref]$bytes) -and $start -le $end -and $end -lt $bytes) { return $bytes }
    } elseif ($StatusCode -eq 200 -and $ContentLength.Trim() -match '\A[0-9]+\z' -and [long]::TryParse($ContentLength, [ref]$bytes)) {
        return $bytes
    }
}
