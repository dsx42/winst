#Requires -Version 5.1

function Get-WinstVersionFromFileVersion {
    <#
    .SYNOPSIS
        detect.method = fileVersion：读命中文件的文件版本（字符串与数值体不一致时按既有口径取舍）。
    .DESCRIPTION
        pathGlob 可能命中多个文件（同一软件的新旧两个版本目录并存时就会这样）：逐个读出文件版本，
        全部交给 Complete-WinstDetectedVersion 挑出最新版本，其余作为「旧版本」返回。
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

    $probe = Resolve-WinstDetectFiles -Context $Context -Detect $Detect -InstallDir $InstallDir
    if (-not $probe.Ok) { return }
    $Result.Found = $true

    foreach ($file in @($probe.Files)) {
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
        if (-not $value) { continue }
        # 同一产品的判定用「抹掉版本目录的路径」：`.NET Runtime\10.0.13\coreclr.dll` 与
        # `10.0.14\coreclr.dll` 抹完相同（同一产品的新旧两版）；VC++ 2019 与 2022 装在不同目录、
        # 本身就是两个可以并存的产品，不会互相报成旧版本
        Add-WinstVersionItem -Result $Result -Version $value -Detail ('文件: {0}' -f $file.FullName) `
            -GroupKey (Get-WinstPathGroupKey -Path $file.FullName)
    }

    if ($probe.HitCount -gt 1 -and (Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
        Write-Host ('  [verbose] 版本检测命中 {0} 个文件，取版本最高的那个' -f $probe.HitCount) -ForegroundColor DarkGray
    }
}
