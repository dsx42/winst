#Requires -Version 5.1

function Test-WinstManifestUrlOrNote {
    <#
    .SYNOPSIS
        校验清单里解析出的下载地址，并按结果「报错」或「记一条提示」——HTTP 来源解析器的统一收口。
    .DESCRIPTION
        服务器返回 404 或 410 时显示调用方传入的下载地址和处理办法。
        遇到人机校验或无法确定文件是否存在时，返回提示供调用方记录。
    .OUTPUTS
        @{ Ok; Error; Note }
        Ok = $false 表示地址无效或远端文件不存在，Error 说明失败原因。
        Note = 非空时应追加到 Notes（无法判断，但不算失败）
    #>
    param(
        [hashtable]$Context,
        [string]$Url,
        [bool]$Skip,
        [hashtable]$Headers = $null,
        [Parameter(Mandatory = $true)][string]$MissingError
    )

    try { Assert-WinstHttpUrl -Url $Url }
    catch { return @{ Ok = $false; Error = $_.Exception.Message; Note = '' } }
    $check = Test-DownloadUrlForManifestCheck -Context $Context -Url $Url -Skip $Skip -Headers $Headers
    if ($check -eq 'missing') {
        return @{ Ok = $false; Error = $MissingError; Note = '' }
    }
    $note = ''
    if ($check -eq 'blocked') {
        # CDN 的人机校验按客户端特征拦截，winst 的 HEAD 探测过不去，但下载引擎能下：算「未能确认」
        $note = '下载地址被站点的人机校验拦下（Cloudflare 挑战），未能确认是否可以访问；清单照常采用，安装时以实际下载结果为准。'
    } elseif ($check -eq 'unknown') {
        $note = '未能确认这个下载地址是否可以访问（服务器没有回应校验请求）。'
    }
    return @{ Ok = $true; Error = ''; Note = $note }
}
