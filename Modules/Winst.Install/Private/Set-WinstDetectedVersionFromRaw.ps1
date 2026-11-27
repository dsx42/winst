#Requires -Version 5.1

function Set-WinstDetectedVersionFromRaw {
    <#
    .SYNOPSIS
        按识别规则从原始文本提取版本号，写入检测结果。
    .DESCRIPTION
        jsonFile、appx、cliVersion 使用 whenNoKind：未声明识别规则时，取第一个像版本号的字符串。
        markerFile 使用 always：识别规则没有提取到版本号时，也会在文件内容中查找版本号。
    .OUTPUTS
        无（原地写 $Result 的 Ok / Version / Detail）
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Result,
        [string]$Raw,
        [string]$Kind,
        $Between,
        [string]$Detail = '',
        [ValidateSet('whenNoKind', 'always')][string]$Fallback = 'whenNoKind'
    )

    $betweenCount = @($Between).Count
    $value = Get-WinstVersionFromText -Text $Raw -Kind $Kind -Between $Between
    if (-not $value -and ($Fallback -eq 'always' -or (-not $Kind -and $betweenCount -eq 0))) {
        $value = Get-WinstFirstVersionLike -Text $Raw
    }

    if ($Detail) { $Result.Detail = $Detail }
    if (-not $value) { return }
    $Result.Ok = $true
    $Result.Version = $value
}
