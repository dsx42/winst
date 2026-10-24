#Requires -Version 5.1

function Get-WinstPackageFilePlans {
    <#
    .SYNOPSIS
        逐个文件判断「缓存里能否直接用」：能直接用就不下载；缺失、需要重取或校验不一致则重新下载。
    .DESCRIPTION
        判定顺序：
          ① 文件不存在 → 需要下载；
          ② 地址与索引记账（fileMeta.url）不一致 → 缓存里是另一份文件，需要下载；
          ③ 已声明校验（hash / hashFile）：索引里记录了该文件的摘要（同算法）时**直接比对校验码**；
             没有记录则计算一次并写回索引，以后不重复计算。
          ④ 未声明校验 → 按 files[].refresh 档位（缺省 auto）与 HEAD 校验器判定。
        各分支的细节见 Get-WinstFilePlan 与 Set-WinstFile*Decision 的说明。
        单文件判定由 Get-WinstFilePlan 承担，本函数只负责遍历与汇总。
    .OUTPUTS
        @( [ordered]@{ Url; Name; Target; Decl; NeedDownload; Reason; Notice; Refresh; RefreshMaxAgeHours; MetaUrl;
                       ExpectedHash; ExpectedAlgorithm; RecordedHash; IndexHash; ManifestHash; ActualHash;
                       ValidatorETag; ValidatorLastModified; ValidatorSize; CheckedAt } )
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)]$Index,
        [Parameter(Mandatory = $true)][string]$Id,
        $Files,
        [switch]$CheckValidators,
        [switch]$FreshMain,
        [string]$FreshMainReason = '版本号取自主包文件信息（软件源里没有版本号），每次都重新取包',
        [switch]$DownloadOnly,
        [string]$SourceVersion = ''
    )

    $plans = @()
    $dir = Join-Path $Context.PkgDir $Id
    $entry = $null
    if ($Index -and $Index.Contains($Id)) { $entry = $Index[$Id] }

    $offline = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Offline)
    $dryRun = [bool]((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).DryRun)
    $canCheckRemote = [bool]($CheckValidators -and -not $offline -and -not $dryRun)

    # 主包序号（files[] 第一条；$FreshMain 时它不沿用缓存，见上面的说明）
    $fileIndex = -1
    foreach ($file in @($Files)) {
        $fileIndex++
        $plans += (Get-WinstFilePlan -Context $Context -File $file -FileIndex $fileIndex -Dir $dir -Entry $entry `
                -Offline:$offline -DryRun:$dryRun -CanCheckRemote:$canCheckRemote -FreshMain:$FreshMain `
                -FreshMainReason $FreshMainReason -DownloadOnly:$DownloadOnly -SourceVersion $SourceVersion)
    }
    return @($plans)
}
