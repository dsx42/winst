#Requires -Version 5.1

function Copy-WinstKeptItems {
    <#
    .SYNOPSIS
        将旧目录中命中 keep 的内容按相对路径复制进交付目录，返回是否命中。
    #>
    param([string]$InstallDir, [string]$SourceDir, [string[]]$Keep, [switch]$KeepTopLevel)

    $rules = @(ConvertTo-WinstKeepRule -Keep $Keep)
    if (-not $rules.Count) { return $false }
    $baseIo = ConvertTo-WinstExtendedPath -Path $InstallDir
    $pending = New-Object 'System.Collections.Generic.Stack[IO.DirectoryInfo]'
    $pending.Push([IO.DirectoryInfo]::new($baseIo))
    $copied = $false
    while ($pending.Count) {
        foreach ($item in $pending.Pop().EnumerateFileSystemInfos()) {
            $relative = $item.FullName.Substring($baseIo.Length + 1)
            $isDirectory = $item -is [IO.DirectoryInfo]
            $isLink = ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
            if (-not (Test-WinstKeepMatch -RelativePath $relative -Name $item.Name -Rules $rules)) {
                if ($isDirectory -and -not $isLink -and -not $KeepTopLevel) { $pending.Push($item) }
                continue
            }
            if ($isLink) { throw ('保留项是重解析点：' + $item.FullName) }
            $destination = Join-WinstPath $SourceDir $relative
            Assert-WinstSafeWritePath -Path $destination
            $existing = Get-WinstFileSystemItem -Path $destination -AllowMissing
            if ($existing -and $isDirectory -ne $existing.PSIsContainer) {
                throw ('保留项与交付目录中的同名条目类型不同：' + $relative)
            }
            $destIo = ConvertTo-WinstExtendedPath -Path $destination
            $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destIo))
            if ($existing -and $isDirectory) {
                $contents = [Management.Automation.WildcardPattern]::Escape($item.FullName) + '\*'
                Copy-Item -Path $contents -Destination $destIo -Recurse -Force -ErrorAction Stop
            } else {
                Copy-Item -LiteralPath $item.FullName -Destination $destIo -Recurse -Force -ErrorAction Stop
            }
            $copied = $true
        }
    }
    return $copied
}
