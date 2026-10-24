#Requires -Version 5.1

function Remove-WinstDownloadResidue {
    <#
    .SYNOPSIS
        清理某个目标文件在缓存目录里的下载残留（同名文件 / 引擎临时文件 / 引擎改名产物）。
    .DESCRIPTION
        下载引擎（FluxDown CLI）在目标名被占用时会把输出改名成「名称 (1).zip」「名称 (2).zip」，
        失败或中断时还会留下「名称.zip.fdownloading」；winst 只认精确文件名，这些残留会让每次重试
        都换一个新名字、永远判成「下载完成后没有找到文件」。
        清理范围**只限本目标**，按精确名字与引擎的改名规则匹配，不碰同目录里的其它包：
          ① 同名文件        <名称>
          ② 引擎临时文件    <名称>.fdownloading
          ③ 引擎改名产物    <主名> (N)<扩展名> 及其 .fdownloading 变体
    .OUTPUTS
        @( 被删除的文件名 )
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $removed = @()
    if (-not $Dir -or -not $Name) { return $removed }
    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return $removed }

    $base = [IO.Path]::GetFileNameWithoutExtension($Name)
    $ext = [IO.Path]::GetExtension($Name)
    $renamePattern = ''
    if ($ext) { $renamePattern = '^' + [regex]::Escape($base) + ' \(\d+\)' + [regex]::Escape($ext) + '(\.fdownloading)?$' }

    foreach ($file in @(Get-ChildItem -LiteralPath $Dir -File -Force -ErrorAction SilentlyContinue)) {
        $n = [string]$file.Name
        $hit = $false
        if ($n -ieq $Name -or $n -ieq ($Name + '.fdownloading')) { $hit = $true }
        elseif ($renamePattern -and [regex]::IsMatch($n, $renamePattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)) { $hit = $true }
        if (-not $hit) { continue }
        try {
            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            $removed += $n
        } catch {
            # 删不掉（被占用等）不致命：随后由下载 / 校验环节给出结论
        }
    }
    return $removed
}
