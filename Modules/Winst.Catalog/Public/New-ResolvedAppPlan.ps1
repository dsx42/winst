#Requires -Version 5.1

function New-ResolvedAppPlan {
    <#
    .SYNOPSIS
        由清单条目 + 来源解析结果生成单个软件的「全流程实际内容」，作为解析锁的一条记录。
    .DESCRIPTION
        覆盖七个阶段：① 下载 ② 解压/安装 ③ 复制/移动 ④ 设置环境变量
        ⑤ 执行预定义命令 ⑥ 检测版本号 ⑦ 卸载操作。{version} 展开为具体版本，
        {installDir} 与 %VAR% 保留符号（安装时按本机 installRoot 展开）。
        本函数只做编排：各阶段由 New-WinstPlan* 按类型生成片段后在这里组装。
    #>
    param(
        [string]$ManifestOrigin,
        $Entry,
        $Resolve,
        [string]$PkgDir = '',
        $Context = $null
    )

    return (New-WinstCatalogAppPlan -ManifestOrigin $ManifestOrigin -Entry $Entry -Resolve $Resolve -PkgDir $PkgDir -Context $Context)
}
