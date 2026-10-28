#Requires -Version 5.1

function Expand-WinstPath {
    <#
    .SYNOPSIS
        展开 %VAR% 形式的环境变量；相对路径以数据根目录为基准解析，结果统一做 GetFullPath 归一化。
    .DESCRIPTION
        installRoot / pkgDir 允许手工写进 config.json（共享 U 盘 / NAS 上也可能被改），
        `..\..\Windows` 这类相对路径必须在这里就被折叠成绝对路径：调用方拿到的要么是归一化后的
        绝对路径，要么是空串；归一化失败时原样返回，由下游路径校验拒绝。

        网络共享只支持 UNC 路径（`\\服务器\共享名\目录`）。映射盘符（`Z:\`）不做转换：
        映射是按登录会话生效的，winst 以管理员身份运行时往往看不到它。入口处的
        Resolve-WinstUncInput 会拒绝映射盘符并提示改写 UNC。
    #>
    param(
        [string]$Path,
        [string]$Base
    )

    if (-not $Path -or -not $Path.Trim()) { return '' }

    $expanded = [Environment]::ExpandEnvironmentVariables($Path.Trim())

    # 路径里带凭据（\\账号:密码@服务器\共享）不是合法路径：账号密码由设置菜单单独询问，
    # 这里明确报错，避免密码继续流向下游（也不会被写进 config.json）。
    if ($expanded.StartsWith('\\')) {
        $body = $expanded.Substring(2)
        $slashIndex = $body.IndexOf('\')
        $head = $(if ($slashIndex -ge 0) { $body.Substring(0, $slashIndex) } else { $body })
        if ($head.LastIndexOf('@') -gt 0 -and $head.Substring(0, $head.LastIndexOf('@')).Contains(':')) {
            throw ('路径里不能写账号密码：UNC 路径只写 \\服务器\共享名\目录。需要认证时请到「设置 → 安装包位置 / 软件安装位置」，输入路径后会单独询问账号与密码。')
        }
    }

    if ($Base -and -not [IO.Path]::IsPathRooted($expanded)) {
        $expanded = Join-WinstPath $Base $expanded
    }
    # 归一化：折叠 . / .. 与重复分隔符。GetFullPath 对非法形态会抛异常，此时原样返回，
    # 由下游的路径校验（Test-WinstSafePathSegment / Test-WinstPathUnderRoot）拒绝，绝不静默拼用。
    try { return [IO.Path]::GetFullPath($expanded) } catch { return $expanded }
}
