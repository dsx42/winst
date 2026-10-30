#Requires -Version 5.1

function New-WinstPlanDetectBlock {
    <#
    .SYNOPSIS
        ⑥ 版本检测定义 → @{ Block; Error }（含名称规则 / 版本识别器 / versionRewrite 的编译校验）。
    #>
    param($Entry, [string]$Version, [string]$Type, [string]$DisplayName)

    $detectBlock = [ordered]@{ method = 'none' }
    $detectObj = Get-EntryValue -Entry $Entry -Key 'detect' -Default $null
    if ($null -ne $detectObj) {
        $method = (Get-EntryString -Entry $detectObj -Key 'method').Trim().ToLowerInvariant()
        if ($method -and @('none', 'registry', 'fileversion', 'markerfile', 'jsonfile', 'appx', 'cliversion') -notcontains $method) {
            return @{ Block = $detectBlock; Error = ('不支持的 detect.method：{0}；可用值为 none / registry / fileVersion / markerFile / jsonFile / appx / cliVersion' -f $method) }
        }
        if ($method) { $detectBlock['method'] = $method }

        foreach ($key in @('name', 'versionKind', 'pathGlob', 'jsonKey', 'versionArgs', 'exe')) {
            $value = Expand-VersionPlaceholder -Text (Get-EntryString -Entry $detectObj -Key $key) -Version $Version
            if ($value) { $detectBlock[$key] = $value }
        }

        $between = @(Get-EntryArray -Entry $detectObj -Key 'versionBetween')
        if ($between.Count -gt 0) { $detectBlock['versionBetween'] = @($between) }

        # 清单自检：匹配规则与版本识别器必须能编译
        if ($detectBlock.Contains('name')) {
            $nameRule = New-MatchRule -Rule ([string]$detectBlock['name']) -Kind '软件名称'
            if (-not $nameRule.Ok) { return @{ Block = $detectBlock; Error = [string]$nameRule.Error } }
        }
        if ($detectBlock.Contains('versionKind')) {
            $kindError = Get-WinstVersionKindError -Kind ([string]$detectBlock['versionKind'])
            if ($kindError) { return @{ Block = $detectBlock; Error = $kindError } }
        }
        # detect.exe只对 cliVersion 有意义
        if ($detectBlock.Contains('exe') -and $detectBlock['method'] -ne 'cliVersion') {
            $errorText = ('detect.exe 只对 cliVersion 有效（指定检测命令运行哪个程序）；当前 detect.method 是 {0}——要检测别的文件请用 pathGlob' -f $detectBlock['method'])
            return @{ Block = $detectBlock; Error = $errorText }
        }
        # 检测侧版本写法归一：编译成规则放进 detect 块，检测与修复时用它改写识别结果
        $detectRewrite = New-WinstVersionRewriteRules -Spec (Get-EntryValue -Entry $detectObj -Key 'versionRewrite' -Default $null)
        if (-not $detectRewrite.Ok) {
            return @{ Block = $detectBlock; Error = ('detect.versionRewrite 有误: {0}' -f $detectRewrite.Error) }
        }
        if ($detectRewrite.Rules.Count -gt 0) { $detectBlock['versionRewrite'] = @($detectRewrite.Rules) }
    } elseif ($Type -eq 'installer') {
        $detectBlock['method'] = 'registry'
        $detectBlock['name'] = ('*' + (ConvertTo-WildcardLiteral -Text $DisplayName) + '*')
    }

    return @{ Block = $detectBlock; Error = '' }
}
