#Requires -Version 5.1

function Get-WinstVersionFromFileVersion {
    <#
    .SYNOPSIS
        detect.method = fileVersion：读命中文件的文件版本（字符串与数值体不一致时按既有口径取舍）。
    #>
    param(
        [hashtable]$Context,
        $Plan,
        $Detect,
        [string]$InstallDir = '',
        [string]$Kind = '',
        $Between = @(),
        [hashtable]$Result
    )

    $probe = Resolve-WinstDetectFirstFile -Context $Context -Detect $Detect -InstallDir $InstallDir
    if (-not $probe.Ok) { return }
    $file = $probe.File
    $Result.Found = $true
    $raw = ''
    try {
        $vi = $file.VersionInfo
        if ($vi) {
            # FileVersion 字符串与数值体（FileVersionRaw）可能不一致：字符串是厂商填的展示值、
            # 可能漏更新。
            # 字符串是数值体的「数字前缀」（同数值、只少尾段——尾段是省略的 0 或构建号）时按字符串算，
            # 否则以数值体为准（编译进二进制的真值）。
            # 两边都先做一次「逗号分隔数字 → 点号」归一：FileZilla 的 FileVersion 字符串是
            # 「3, 71, 1, 0」（版本资源的 FILEVERSION 原样写法），不归一会判不出前缀关系，
            # 保留下来又会把版本识别成 `71`（见 ConvertTo-WinstFileVersionText）。
            $rawNumber = ConvertTo-WinstFileVersionText -Text ([string]$vi.FileVersionRaw)
            if (-not $rawNumber) { $rawNumber = ConvertTo-WinstFileVersionText -Text ([string]$vi.ProductVersionRaw) }
            $raw = ConvertTo-WinstFileVersionText -Text ([string]$vi.FileVersion)
            if (-not $raw) { $raw = ConvertTo-WinstFileVersionText -Text ([string]$vi.ProductVersion) }
            if ($rawNumber -and (Test-WinstNumericVersionPrefix -Prefix $raw -Value $rawNumber)) {
                # 字符串是数值体的前缀（或两者一致）：按字符串算，保持既有口径
            } elseif ($rawNumber) {
                $raw = $rawNumber
            }
            if (-not $raw) { $raw = ConvertTo-WinstFileVersionText -Text ([string]$vi.FileVersionRaw) }
            if (-not $raw) { $raw = ConvertTo-WinstFileVersionText -Text ([string]$vi.ProductVersionRaw) }
        }
    } catch { $raw = '' }
    $value = Get-WinstVersionFromText -Text $raw -Kind $Kind -Between $Between
    # 文件版本号本身就是版本：没声明识别器时按「第一个像版本号的内容」兜底
    if (-not $value -and -not $Kind -and -not (@($Between).Count -gt 0)) { $value = Get-WinstFirstVersionLike -Text $raw }
    $Result.Detail = ('文件: {0}' -f $file.FullName)
    if ($probe.HitCount -gt 1 -and (Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
        Write-Host ('  [verbose] 版本检测命中多个文件，取第一个: {0}' -f $file.FullName) -ForegroundColor DarkGray
    }
    if (-not $value) { return }
    $Result.Ok = $true
    $Result.Version = $value
}
