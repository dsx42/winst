#Requires -Version 5.1

function Get-Winst7zEntryPaths {
    <#
    .SYNOPSIS
        列出压缩包里的条目路径（`7z l -slt` 技术列表：解析 `Path =` 行，默认只取文件，DirectoriesOnly 时只取目录；跳过压缩包自身的元信息块）。
    .OUTPUTS
        @{ Ok; Paths; Error }
    #>
    param(
        [Parameter(Mandatory = $true)][string]$SevenZip,
        [Parameter(Mandatory = $true)][string]$ArchivePath,
        [switch]$DirectoriesOnly,
        [string]$PathPattern, [switch]$LeafOnly
    )

    $result = @{ Ok = $false; Paths = @(); Error = '' }
    if (-not (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) {
        $result.Error = ('压缩包不存在: {0}' -f $ArchivePath)
        return $result
    }

    $paths = New-Object 'System.Collections.Generic.List[string]'
    $diagnostic = @{ First = '' }
    $read = {
        param($reader)
        $current = ''
        $isDir = $false
        $hasAttrs = $false
        while ($true) {
            $line = $reader.ReadLine()
            if ($null -ne $line -and -not $diagnostic.First -and $line.Trim()) { $diagnostic.First = $line.Trim() }
            if ($null -eq $line -or $line -match '^Path\s*=\s*(.+)\s*$') {
                if ($current -and $hasAttrs -and ($isDir -eq [bool]$DirectoriesOnly)) {
                    $candidate = $current
                    if ($LeafOnly) { $candidate = [IO.Path]::GetFileName($current) }
                    if (-not $PathPattern -or $candidate -like $PathPattern) {
                        $paths.Add($current)
                        if ($PathPattern) {
                            # 命中后仍排空输出，子进程才能正常退出。
                            $buffer = New-Object char[] 8192
                            while ($reader.Read($buffer, 0, $buffer.Length) -gt 0) { }
                            break
                        }
                    }
                }
                if ($null -eq $line) { break }
                $current = $Matches[1].Trim()
                $isDir = $false
                $hasAttrs = $false
            } elseif ($line -match '^Folder\s*=\s*(.+)\s*$') {
                $isDir = $Matches[1].Trim() -eq '+'
                $hasAttrs = $true
            } elseif ($line -match '^Attributes\s*=') {
                $hasAttrs = $true
                if ($line -match '^Attributes\s*=\s*\S*D') { $isDir = $true }
            }
        }
    }.GetNewClosure()
    try {
        foreach ($value in @($SevenZip, $ArchivePath)) {
            if (-not (Test-WinstArgumentSafe -Value $value)) { throw '7-Zip 路径含有引号或控制字符' }
        }
        $run = Invoke-WinstCapturedCommand -FilePath $SevenZip -Arguments ('l -slt -sccUTF-8 {0}' -f (Format-WinstCommandArgument -Value $ArchivePath)) -NoTimeout -ReadOutput $read
        if (-not $run.Ok) { throw $run.Error }
        if ($run.ExitCode -notin @(0, 1)) { throw ('7z 退出码 {0}：{1}' -f $run.ExitCode, $diagnostic.First) }
    } catch {
        $result.Error = ('列不出压缩包内容（{0}）' -f $_.Exception.Message)
        return $result
    }
    $result.Ok = $true
    $result.Paths = @($paths.ToArray())
    return $result
}
