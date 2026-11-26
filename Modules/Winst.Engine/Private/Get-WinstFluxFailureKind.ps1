#Requires -Version 5.1

function Get-WinstFluxFailureKind {
    param([string]$Message, [int]$ExitCode = -1, [long]$ReceivedBytes, [ref]$StatusCode)

    if ($ExitCode -eq 7) { return 'Cancelled' }
    # FluxDown 的诊断可能包含下载地址。先去掉地址，避免把路径、令牌里的数字认成状态码。
    $reason = $Message -replace '(?i)(?:https?|ftp)://[^\s)]+', ''
    if ($reason -match '(?i)\b(?:GET|HEAD|HTTP(?:/[\d.]+)?(?:\s+(?:client |server )?error)?|status(?: code)?)\s*[:=( ]\s*([45]\d\d)\b' -or
        $reason -match '(?i)\b([45]\d\d)\s+(?:Client Error|Server Error|Bad Request|Unauthorized|Forbidden|Not Found|Request Timeout|Too Many Requests|Internal Server Error|Bad Gateway|Service Unavailable|Gateway Timeout)\b') {
        if ($StatusCode) { $StatusCode.Value = [int]$Matches[1] }
        return 'Http'
    }
    if ($reason -match '(?i)\bdisk full\b|no space left|access (?:is )?denied|permission denied|os error (?:5|28|112)\b') { return 'Disk' }
    if ($reason -match '\[net:(dns|refused|connect-timeout)\]|dns error|connection refused|connect(?:ion)? timed out|os error (?:10061|11001)\b') {
        if ($ReceivedBytes -eq 0) { return 'Connect' }
    }
    if (($ReceivedBytes -gt 0 -or $reason -match 'response body ended after [1-9]\d* of') -and
        ($reason -match '\[net:(reset|timeout|interrupted|stalled)\]|connection reset|timed? ?out|incomplete download|unexpected eof|end of file before|error reading a body|os error 10054\b' -or $ExitCode -eq 2)) {
        return 'Interrupted'
    }
    return 'Other'
}
