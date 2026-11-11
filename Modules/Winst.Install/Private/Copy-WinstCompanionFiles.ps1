#Requires -Version 5.1

function Copy-WinstCompanionFiles {
    <#
    .SYNOPSIS
        把配套文件按 dest 落位到安装目录。
    .OUTPUTS
        @{ Ok; Files; Rules; UpdatedNames; Error }，Files 是所有当前声明的相对路径 / 目录，
        Rules 记录落位规则，UpdatedNames 只列出本次实际复制或解压的附件名。
    .DESCRIPTION
        复制到 dest；声明 extract 的配套文件是压缩包，解压到 dest 目录（该文件自己的 stripTopDir）。
        dest 非法（`.` / `..` / 绝对路径）或解压 / 复制失败即报错，不做静默跳过。
    #>
    param(
        [hashtable]$Context,
        [Parameter(Mandatory = $true)]$Files,
        [Parameter(Mandatory = $true)][string]$PkgDir,
        [Parameter(Mandatory = $true)][string]$InstallDir,
        [switch]$OnlyChanged,
        [string[]]$ChangedNames = @(),
        $PreviousRules = $null
    )

    $result = @{ Ok = $true; Files = @(); Rules = (New-WinstOrdinalDictionary); UpdatedNames = @(); Error = '' }
    if (-not $Files) { return $result }
    $list = @($Files)
    for ($i = 1; $i -lt $list.Count; $i++) {
        $file = $list[$i]
        $dest = (Get-EntryString -Entry $file -Key 'dest').Trim()
        $extract = Get-EntryBool -Entry $file -Key 'extract'
        if (-not $dest) {
            if ($extract) {
                $result.Ok = $false
                $result.Error = ('声明了解压（extract）的附加文件要写出解压目标目录（dest）：{0}' -f (Get-EntryString -Entry $file -Key 'url'))
                return $result
            }
            continue
        }
        $safeDest = Resolve-WinstSafeChildPath -Root $InstallDir -Child $dest -Label '附加文件的落位路径'
        if (-not $safeDest.Ok) {
            $result.Ok = $false
            $result.Error = [string]$safeDest.Error
            return $result
        }
        $destPath = [string]$safeDest.Path
        # 落位目标经过 junction / 符号链接时会被写到安装目录之外。这里必须无条件检查：
        # 目标尚不存在时也要复核父级路径链与边界，无法读取属性时立即中止。
        if (Test-WinstPathHasReparsePoint -Path $destPath -Root $InstallDir) {
            $result.Ok = $false
            $result.Error = ('附加文件的落位路径经过重解析点或位于安装目录之外，已拒绝：{0}' -f $dest)
            return $result
        }
        $name = Get-EntryString -Entry $file -Key 'name'
        if (-not $name) { $name = Get-FileNameFromUrl -Url (Get-EntryString -Entry $file -Key 'url') }
        $stripValue = Get-EntryValue -Entry $file -Key 'stripTopDir' -Default $false
        if ($null -eq $stripValue) { $stripValue = $false }
        $signature = Get-WinstCompanionLayoutSignature -File $file
        $result.Rules[$name] = $signature
        $result.Files += $dest
        $pathType = 'Leaf'
        if ($extract) { $pathType = 'Container' }
        if ($OnlyChanged -and $ChangedNames -notcontains $name -and
                (Get-EntryString -Entry $PreviousRules -Key $name) -ceq $signature -and
                (Test-Path -LiteralPath $destPath -PathType $pathType)) { continue }
        $source = Join-WinstPath $PkgDir $name
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
            # 清单要落位这个文件、而缓存里没有它（下载阶段没成功）时**报错**而不是静默跳过：
            # 否则会打印「已更新 N 个附加文件」，实际却什么都没落
            $result.Ok = $false
            $result.Error = ('附加文件不在缓存里：{0}（{1}）' -f $name, $PkgDir)
            return $result
        }
        if ($extract) {
            $engine = Confirm-WinstExtractEngine -Context $Context -Quiet
            if (-not $engine.Ok) {
                $result.Ok = $false
                $result.Error = ('解压引擎不可用（附加文件 {0}）：{1}' -f $name, $engine.Error)
                return $result
            }
            # 完整解压后直接把选中的内容合并到 dest，临时解压树由本次调用清理。
            $expand = Expand-WinstArchiveLayout -Context $Context -ArchivePath $source -DestDir $destPath -StripTopDir $stripValue
            if (-not $expand.Ok) {
                $result.Ok = $false
                $result.Error = ('附加文件解压失败（{0}）：{1}' -f $dest, $expand.Error)
                return $result
            }
            try {
                $landing = Move-WinstStagedInstall -StageDir $expand.TempRoot -SourceDir $expand.SourceDir -InstallDir $destPath
                if (-not $landing.Ok) {
                    $result.Ok = $false
                    $result.Error = ('附加文件落位失败（{0}）：{1}' -f $dest, $landing.Error)
                    return $result
                }
                $result.UpdatedNames += $name
            } finally {
                if ($expand.TempRoot -and (Test-Path -LiteralPath $expand.TempRoot)) { Clear-WinstInstallDir -Dir $expand.TempRoot }
            }
            continue
        }
        $target = $destPath
        $targetParent = Split-Path -Parent $target
        if ($targetParent -and -not (Test-Path -LiteralPath $targetParent -PathType Container)) {
            $null = New-Item -ItemType Directory -Path $targetParent -Force -ErrorAction SilentlyContinue
            # 新建出来的父目录同样可能是并行放进去的 junction：建完再复核一次整条路径链
            if (Test-WinstPathHasReparsePoint -Path $targetParent -Root $InstallDir) {
                $result.Ok = $false
                $result.Error = ('附加文件的落位路径经过重解析点或位于安装目录之外，已拒绝：{0}' -f $dest)
                return $result
            }
        }
        try { Copy-Item -LiteralPath $source -Destination $target -Force -ErrorAction Stop } catch {
            $result.Ok = $false
            $result.Error = ('附加文件落位失败（{0}）：{1}' -f $dest, $_.Exception.Message)
            return $result
        }
        $result.UpdatedNames += $name
    }
    return $result
}
