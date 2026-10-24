#Requires -Version 5.1

function Invoke-WinstPostInstallCopy {
    <#
    .SYNOPSIS
        执行 postInstallCopy：安装目录内的复制 / 改名（`move: true` = 改名）。
    .DESCRIPTION
        `from` 支持 `*` 通配；`from` 不存在或命中多个文件即报错。
    .OUTPUTS
        @{ Ok; Error }
    #>
    param(
        [Parameter(Mandatory = $true)]$Plan,
        [Parameter(Mandatory = $true)][string]$InstallDir
    )

    foreach ($rule in @(Get-EntryArray -Entry $Plan -Key 'postInstallCopy')) {
        $fromText = Get-EntryString -Entry $rule -Key 'from'
        $toText = Get-EntryString -Entry $rule -Key 'to'
        if (-not $fromText -or -not $toText) { continue }

        $fromResolved = Resolve-WinstSafeChildPattern -Root $InstallDir -Child $fromText -Label 'postInstallCopy.from'
        if (-not $fromResolved.Ok) { return @{ Ok = $false; Error = [string]$fromResolved.Error } }
        $toResolved = Resolve-WinstSafeChildPath -Root $InstallDir -Child $toText -Label 'postInstallCopy.to'
        if (-not $toResolved.Ok) { return @{ Ok = $false; Error = [string]$toResolved.Error } }
        $fromPath = [string]$fromResolved.Path
        $toPath = [string]$toResolved.Path

        $hits = @()
        try { $hits = @(Get-Item -Path $fromPath -Force -ErrorAction SilentlyContinue) } catch { $hits = @() }
        if ($hits.Count -eq 0) {
            return @{ Ok = $false; Error = ('要{0}的文件不存在：{1}' -f $(if (Get-EntryBool -Entry $rule -Key 'move') { '改名' } else { '复制' }), $fromPath) }
        }
        if ($hits.Count -gt 1) {
            $names = @($hits | ForEach-Object { $_.Name })
            return @{ Ok = $false; Error = ('要处理的文件匹配到多个（{0}）：{1}' -f ($names -join '、'), $fromPath) }
        }

        $source = $hits[0]
        if (-not (Test-WinstPathUnderRoot -Path $source.FullName -Root $InstallDir) -or
                (Test-WinstPathHasReparsePoint -Path $source.FullName -Root $InstallDir)) {
            return @{ Ok = $false; Error = ('拒绝从安装目录之外或重解析点读取文件：{0}' -f $source.FullName) }
        }
        if (Test-WinstPathHasReparsePoint -Path $toPath -Root $InstallDir) {
            return @{ Ok = $false; Error = ('拒绝通过重解析点写入目标：{0}' -f $toPath) }
        }
        $toParent = Split-Path -Parent $toPath
        if ($toParent -and -not (Test-Path -LiteralPath $toParent -PathType Container)) {
            $null = New-Item -ItemType Directory -Path $toParent -Force -ErrorAction SilentlyContinue
        }
        try {
            if (Get-EntryBool -Entry $rule -Key 'move') {
                Move-Item -LiteralPath $source.FullName -Destination $toPath -Force -ErrorAction Stop
            } else {
                Copy-Item -LiteralPath $source.FullName -Destination $toPath -Force -ErrorAction Stop
            }
        } catch {
            return @{ Ok = $false; Error = ('{0} 失败：{1}' -f $(if (Get-EntryBool -Entry $rule -Key 'move') { '改名' } else { '复制' }), $_.Exception.Message) }
        }
    }
    return @{ Ok = $true; Error = '' }
}
