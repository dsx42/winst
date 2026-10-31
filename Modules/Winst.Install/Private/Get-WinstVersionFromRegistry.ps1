#Requires -Version 5.1

function Get-WinstVersionFromRegistry {
    <#
    .SYNOPSIS
        detect.method = registry：从系统安装记录（Uninstall 键）读版本。
    .DESCRIPTION
        名称规则可能命中**多条**记录，典型有两种：
          - 同一个软件的新旧两个版本并存（升级后旧版本没被清掉）；
          - 一个安装器留下的两层记录：外层 burn 引导包（自带 exe 卸载器，版本号是产品版本，
            如 `10.0.14`）+ 内层 MSI（MsiExec 卸载，版本号是 MSI 内部编号，如 `80.56.61678`）。
        两层记录的版本号体系完全不同，混在一起比较会选出 MSI 那个内部编号。因此：

        有非 MsiExec 的记录时只用它们（那是产品自报版本，且卸载时会连带移除内层 MSI）；
        全是 MsiExec 记录时才全部参与（如 MSVC 各年份运行库，都是独立产品）。

        选出的版本号全部交给 Complete-WinstDetectedVersion 挑出最新版本，其余作为「旧版本」返回。
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

    $query = @{}
    $hits = @(Get-WinstRegistryEntriesForPlan -Plan $Plan -InstallDir $InstallDir -Status $query)
    $Result['QuerySucceeded'] = [bool]$query.Ok
    if (-not $query.Ok) { $Result.Note = ('查询系统安装记录未完成：{0}' -f $query.Error) }
    if ($hits.Count -eq 0) { return }

    $Result.Found = $true
    $nonMsi = @()
    foreach ($hit in $hits) {
        if (-not (Test-WinstRegistryEntryIsMsi -Entry $hit)) { $nonMsi += $hit }
    }
    $chosenHits = $nonMsi
    if ($chosenHits.Count -eq 0) { $chosenHits = @($hits) }

    foreach ($chosen in $chosenHits) {
        $displayName = Get-EntryString -Entry $chosen -Key 'DisplayName'
        $probe = @{ Ok = $false; Found = $true; Version = ''; Detail = '' }
        Set-WinstDetectedVersionFromRaw -Result $probe -Raw ([string]$chosen['DisplayVersion']) `
            -Kind $Kind -Between $Between -Detail ('系统安装记录: {0}' -f $displayName)
        if (-not $probe.Ok -or -not $probe.Version) { continue }
        if (-not $Result.Detail) { $Result.Detail = [string]$probe.Detail }
        Add-WinstVersionItem -Result $Result -Version ([string]$probe.Version) -Detail ([string]$probe.Detail) `
            -RecordKey ([string]$chosen['KeyPath']) -GroupKey (Get-WinstProductNameKey -DisplayName $displayName)
    }
}
