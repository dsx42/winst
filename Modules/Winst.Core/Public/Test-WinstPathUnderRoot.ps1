#Requires -Version 5.1

function Test-WinstPathUnderRoot {
    <#
    .SYNOPSIS
        判断某个路径是否确实位于指定根目录之下（按归一化后的完整路径比较，区分目录边界）。
    .DESCRIPTION
        字符串前缀比较会把 `C:\App\FooBar` 当成 `C:\App\Foo` 的子目录，因此比较前统一 GetFullPath，
        并在根目录末尾补分隔符。`-AllowEqual` 用于「根目录本身也合法」的场景。

        **「等于根目录」必须先判**：`GetFullPath` 会保留末尾分隔符，`C:\App\Foo\` 与 `C:\App\Foo`
        是同一个目录，但只有后者等于 `$rootTrim`。若把相等判断写成 `$AllowEqual -and 相等`，
        带尾分隔符的同一目录会落到前缀分支，对 `C:\App\Foo\` 的前缀是 `C:\App\Foo\`，
        于是「不传 -AllowEqual」时反而放行——同一个目录两种写法结果相反。
        因此先比相等：命中即按 `-AllowEqual` 返回，不再走前缀比较。
    .OUTPUTS
        [bool]
    #>
    param(
        [string]$Path,
        [string]$Root,
        [switch]$AllowEqual
    )

    if (-not $Path -or -not $Root) { return $false }
    $fullPath = ''
    $fullRoot = ''
    try {
        $fullPath = [IO.Path]::GetFullPath((ConvertTo-WinstPlainDevicePath -Path ([string]$Path)))
        $fullRoot = [IO.Path]::GetFullPath((ConvertTo-WinstPlainDevicePath -Path ([string]$Root)))
    } catch {
        return $false
    }
    $rootTrim = $fullRoot.TrimEnd('\', '/')
    if (-not $rootTrim) { return $false }
    $pathTrim = $fullPath.TrimEnd('\', '/')

    # 同一个目录（含尾分隔符 / 正斜杠等等价写法）：结果只由 -AllowEqual 决定
    if ($pathTrim -ieq $rootTrim) { return [bool]$AllowEqual }

    # 子路径：用归一化后的 $pathTrim 比较，避免 $fullPath 的尾分隔符参与前缀匹配
    $prefix = $rootTrim + [IO.Path]::DirectorySeparatorChar
    return $pathTrim.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
}
