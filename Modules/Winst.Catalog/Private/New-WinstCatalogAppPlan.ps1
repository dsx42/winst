#Requires -Version 5.1

function New-WinstCatalogAppPlan {
    <#
    .SYNOPSIS
        校验一个清单条目，解析来源并生成解析锁记录。
    .DESCRIPTION
        覆盖七个阶段：① 下载 ② 解压/安装 ③ 复制/移动 ④ 设置环境变量
        ⑤ 执行预定义命令 ⑥ 检测版本号 ⑦ 卸载操作。{version} 展开为具体版本，
        {installDir} 与 %VAR% 保留符号（安装时按本机 installRoot 展开）。
        本函数只做编排：各阶段由 New-WinstPlan* 按类型生成片段后在这里组装。
    #>
    param(
        [string]$ManifestOrigin,
        $Entry,
        [hashtable]$Context
    )

    $kind = ''
    try {
        $Entry = ConvertTo-WinstManifestEntry -Entry $Entry
        $kind = [string]$Entry['source']['kind']
        $packageVersionSpec = Get-WinstPackageVersionSpec -Source $Entry['source']
    }
    catch {
        $failure = New-SourceResolveResult -Kind $kind
        $failure.Error = $_.Exception.Message
        return (New-WinstPlanBase -ManifestOrigin $ManifestOrigin -Entry $Entry -Resolve $failure).Plan
    }

    $resolve = Resolve-WinstNormalizedAppSource -Context $Context -Entry $Entry

    $base = New-WinstPlanBase -ManifestOrigin $ManifestOrigin -Entry $Entry -Resolve $resolve
    $plan = $base.Plan
    if ($base.Error) { return $plan }

    $versionState = Resolve-WinstPlanVersion -Plan $plan -Entry $Entry -Context $Context -Notes $base.Notes -PackageVersionSpec $packageVersionSpec
    if ($versionState.Error) { return $plan }
    $plan = Complete-WinstInstallPlan -Plan $plan -Entry $Entry -Version $versionState.Version -Notes $versionState.Notes
    if (-not $plan.ok) { return $plan }

    # package 来源按 compare 比较远端与缓存文件，结论存入解析锁；可能读取 HTTP 校验器或摘要。
    # （remoteFresh：changed / unchanged / unknown）——各列表 / 详情据此提示「远端有新包」，
    # 展示时只读锁；判据不可比时记 unknown。
    if ([bool]$plan['versionFromPackage']) {
        Set-WinstPlanRemoteFresh -Plan $plan -Context $Context
    }

    return $plan
}
