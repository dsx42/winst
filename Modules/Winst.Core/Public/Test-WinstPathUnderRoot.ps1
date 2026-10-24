#Requires -Version 5.1

function Test-WinstPathUnderRoot {
    <#
    .SYNOPSIS
        判断某个路径是否确实位于指定根目录之下（按归一化后的完整路径比较，区分目录边界）。
    .DESCRIPTION
        字符串前缀比较会把 `C:\App\FooBar` 当成 `C:\App\Foo` 的子目录，因此比较前统一 GetFullPath，
        并在根目录末尾补分隔符；`-AllowEqual` 用于「根目录本身也合法」的场景。
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
    if ($AllowEqual -and ($pathTrim -ieq $rootTrim)) { return $true }
    $prefix = $rootTrim + [IO.Path]::DirectorySeparatorChar
    return $fullPath.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)
}
