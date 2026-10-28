#Requires -Version 5.1

function Test-WinstManifestUrlOrNote {
    <#
    .SYNOPSIS
        校验清单里解析出的下载地址，并按结果「报错」或「记一条提示」——四个解析器的统一收口。
    .DESCRIPTION
        direct / github / page / json 四个来源都要做同一件事：

            $check = Test-DownloadUrlForManifestCheck ...
            if ($check -eq 'missing') { 报错并中止 }
            if ($check -eq 'unknown') { 追加一条「未能确认」的提示，继续 }
            if ($check -eq 'blocked') { 追加一条「被人机校验拦下」的提示，继续 }

        四个来源只有「404 的错误文案」不同（direct 提示检查版本号或模板；github 附带该发布实际包含的
        文件名；page 指向页面链接已失效；json 指向接口地址失效）。

        **只有 missing 文案是真正的差异**，其余（blocked / unknown 的提示语、skip 语义、探测口径）必须一致 ——
        否则改一处提示、另一处容易漏改。
    .OUTPUTS
        @{ Ok; Error; Note }
        Ok   = $false 表示探测到 404，调用方应中止并把 Error 作为失败原因
        Note = 非空时应追加到 Notes（无法判断，但不算失败）
    #>
    param(
        [hashtable]$Context,
        [string]$Url,
        [bool]$Skip = $false,
        [hashtable]$Headers = $null,
        [Parameter(Mandatory = $true)]$MissingError
    )

    $check = Test-DownloadUrlForManifestCheck -Context $Context -Url $Url -Skip $Skip -Headers $Headers
    if ($check -eq 'missing') {
        # 允许传 scriptblock：只在真的 404 时才求值，用于「报错里还要附上额外信息」的来源
        # （如 github 要列出该发布实际包含哪些文件 —— 那需要再发一次请求，不该在成功路径上做）
        $errorText = $MissingError
        if ($MissingError -is [scriptblock]) { $errorText = [string](& $MissingError) }
        return @{ Ok = $false; Error = $errorText; Note = '' }
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
