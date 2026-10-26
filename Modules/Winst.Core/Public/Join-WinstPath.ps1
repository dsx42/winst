#Requires -Version 5.1

function Join-WinstPath {
    <#
    .SYNOPSIS
        拼接两个路径片段，不依赖 PowerShell 的驱动器解析。

    .DESCRIPTION
        `Join-Path` 会先在 PowerShell 驱动器表里解析父路径所在的驱动器：父路径指向一个
        **当前进程看不到的驱动器**时（管理员身份运行时的映射盘 / subst 盘、别人会话里映射的
        网络盘），它会直接抛 `DriveNotFoundException`——报错文案就是「找不到驱动器。名为“Y”的
        驱动器不存在」，即使这个路径只是要拼一个字符串、后面根本不需要访问它。

        `[IO.Path]::Combine` 只做字符串拼接，不查驱动器表，因此对「路径现在不可访问、
        但配置值原样保留」的场景是安全的：配置文件里的安装位置 / 安装包位置可以指向
        离线盘、别人机器上才存在的盘，winst 拼出路径后再由 Test-Path / Test-WinstPathUnderRoot
        这类判断得出「不存在」，而不是在拼接阶段就抛异常。

        传空串时原样返回另一侧（不追加分隔符）：调用方常常把「可能为空的 id / 子目录」
        直接拼进来。

    .OUTPUTS
        [string]

    .EXAMPLE
        Join-WinstPath 'Y:\winst' 'WinMerge'   # => Y:\winst\WinMerge（Y: 不可见也不报错）
    #>
    param(
        [Parameter(Position = 0)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Path = '',

        [Parameter(Position = 1)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Child = ''
    )

    if (-not $Path) { return $Child }
    if (-not $Child) { return $Path }
    return [IO.Path]::Combine($Path, $Child)
}
