#Requires -Version 5.1

function Invoke-WinstPackageDownloadLoop {
    <#
    .SYNOPSIS
        逐个文件取包：命中缓存直接跳过；缺失 / 需重取则下载（含离线特例、引擎引导、失效地址重试、完整性校验）。
    .OUTPUTS
        @{ Ok; Error; Network; Downloaded; Names; Any }
    #>
    param([hashtable]$Context, $Plans, [string]$PkgDir, [string]$Id, [string]$DisplayName, [string]$SourceName,
        [string]$Version, [switch]$Offline, [switch]$Quiet)

    $downloaded = @()
    $downloadedNames = @()
    $downloadedAny = $false
    $engineReady = $false
    $fileSeq = -1
    foreach ($filePlan in @($Plans)) {
        $fileSeq++
        $url = [string]$filePlan['Url']
        $name = [string]$filePlan['Name']
        $target = [string]$filePlan['Target']
        if (-not $name -or -not $target -or -not $url) {
            return @{ Ok = $false; Error = ('下载信息不完整（{0}）' -f $DisplayName); Network = $false; Downloaded = $downloaded; Names = $downloadedNames; Any = $downloadedAny }
        }
        # refresh 取值写错之类只在 --verbose 提示，不占正常输出
        if ($filePlan['Notice'] -and (Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
            Write-Host ('  [verbose] {0}' -f [string]$filePlan['Notice']) -ForegroundColor DarkGray
        }
        # Hint：拿不到校验器时「本次按已缓存处理」这类必须让用户看见的一行
        if ($filePlan['Hint'] -and -not $Quiet) {
            Write-Host ('    提示: {0}' -f [string]$filePlan['Hint']) -ForegroundColor DarkYellow
        }

        if (-not $filePlan['NeedDownload']) {
            $downloaded += $target
            continue
        }

        if ($filePlan['Reason'] -and -not $Quiet) {
            Write-Host ('    {0}: {1}' -f $name, $filePlan['Reason']) -ForegroundColor DarkYellow
        }
        if ($Offline) {
            # 离线时不能拿「当前运行的脚本」顶替安装包：缓存里的目标名是清单声明的文件名
            # （winst 是 winst.zip，type: portable），把 winst.ps1 的内容写进 winst.zip 会让后续
            # 解压必然失败（7z / tar / Expand-Archive 都打不开），报错却是「包损坏」。
            # 离线安装 winst 自身请走 Install-WinstSelf 的本地包分支：
            #     winst install winst --from <winst.zip 或已解压目录>
            $offlineError = ('离线缺包：{0} 的安装包不在缓存里。请在联网机器上刷新缓存（bundle pack / update --download-only）后重试。' -f $DisplayName)
            if ($Id -ieq 'winst') {
                $offlineError = ('离线缺包：{0} 的安装包不在缓存里。离线安装 winst 自身请用 winst install winst --from <winst.zip 或已解压目录>。' -f $DisplayName)
            }
            if (Test-Path -LiteralPath $target -PathType Leaf) {
                $offlineError = ('离线缓存无法验证：{0} 的现有安装包未通过当前完整性规则；文件已保留，请在联网机器上刷新缓存后重试。' -f $DisplayName)
            }
            return @{
                Ok = $false; Network = $true; Downloaded = $downloaded; Names = $downloadedNames; Any = $downloadedAny
                Error = $offlineError
            }
        }
        # 校验码不一致 / 旧包损坏：仅在确定可以联网重取后删除；离线失败必须保留原文件。
        if (Test-Path -LiteralPath $target -PathType Leaf) {
            Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
        }
        if (-not $engineReady) {
            $engine = Confirm-WinstDownloadEngine -Context $Context -Quiet:$Quiet
            if (-not $engine.Ok) {
                return @{ Ok = $false; Error = ('下载引擎不可用：{0}' -f $engine.Error); Network = $true; Downloaded = $downloaded; Names = $downloadedNames; Any = $downloadedAny }
            }
            $engineReady = $true
            # 引导下载引擎时可能已把本包一并取下（引擎引导包与目标包常是同一个文件），避免重复下载
            if (Test-Path -LiteralPath $target -PathType Leaf) {
                $recheck = Test-WinstFileIntegrity -Context $Context -FilePath $target -FileDecl $filePlan['Decl'] `
                    -FileUrl $url -SourceVersion $Version
                if ($recheck.Ok) {
                    Set-WinstFilePlanIntegrityFromCheck -FilePlan $filePlan -Check $recheck
                    $downloaded += $target
                    $downloadedNames += $name
                    continue
                }
            }
        }

        # 下载前先清掉本目标的残留（上次失败留下的 .fdownloading、引擎改名产出的「名称 (1).zip」）：
        # 不清的话引擎看到同名文件会把这次输出改成「名称 (1).zip」，winst 按期望名找不到就永远重试
        $residue = @(Remove-WinstDownloadResidue -Dir $PkgDir -Name $name)
        if ($residue.Count -gt 0 -and -not $Quiet) {
            Write-Host ('    已清理上次未完成的下载残留: {0}' -f ($residue -join '、')) -ForegroundColor DarkGray
        }
        if (-not $Quiet) { Write-Host ('    正在下载 {0} …' -f $name) -ForegroundColor Gray }
        $beforeFiles = @(Get-ChildItem -LiteralPath $PkgDir -File -Force -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
        $dl = Invoke-WinstPackageDownload -Context $Context -Url $url -DestDir $PkgDir -FileName $name
        if (-not $dl.Ok) {
            # 带时效的地址过期后必然下载失败：
            # 重新解析该条目的来源、用新地址再试一次。只认「同一个文件」（名字与版本都要对得上），
            # 免得软件源已经换了新版本时把新版本当成目标版本下载；只试一次，不写回解析锁。
            $live = Get-WinstLiveResolvedFileUrl -Context $Context -Id $Id -PreferSource $SourceName -Index $fileSeq -FileName $name
            $retryUrl = ''
            if ($live.Ok -and $live.Url -and ([string]$live.Url -cne $url) -and ([string]$live.Name -ieq $name)) {
                $sameVersion = $true
                if ([string]$live.Version -and $Version) {
                    $sameVersion = ((Compare-WinstVersion -A ([string]$live.Version) -B $Version) -eq 0)
                }
                if ($sameVersion) { $retryUrl = [string]$live.Url }
            }
            if ($retryUrl) {
                if (-not $Quiet) { Write-Host '    下载地址可能已失效，已重新从软件源取回下载地址，正在重试 …' -ForegroundColor DarkYellow }
                $retryDl = Invoke-WinstPackageDownload -Context $Context -Url $retryUrl -DestDir $PkgDir -FileName $name
                if ($retryDl.Ok) {
                    $dl = $retryDl
                    $url = $retryUrl
                    # 索引 fileMeta 记新地址：下次按「地址变化」判定自然会重新取
                    $filePlan['Url'] = $retryUrl
                } else {
                    $dl = @{ Ok = $false; Error = ('{0}；重新解析软件源后重试仍失败：{1}' -f $dl.Error, $retryDl.Error) }
                }
            } elseif ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) {
                if ($live.Ok) {
                    Write-Host ('  [verbose] 重新解析软件源后地址没有变化（或已换版本），不重试: {0}' -f [string]$live.Name) -ForegroundColor DarkGray
                } else {
                    Write-Host ('  [verbose] 重新解析软件源失败：{0}' -f [string]$live.Error) -ForegroundColor DarkGray
                }
            }
            if (-not $dl.Ok) {
                return @{ Ok = $false; Error = ('下载 {0} 失败：{1}' -f $name, $dl.Error); Network = $true; Downloaded = $downloaded; Names = $downloadedNames; Any = $downloadedAny }
            }
        }
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
            # 引擎在目标名被占用时会把输出改名成「名称 (1).zip」：只认本次新出现的那个文件并归位
            $adopt = Resolve-WinstDownloadedFile -Dir $PkgDir -Name $name -BeforeFiles $beforeFiles
            if ([string]$adopt.Note -and -not $Quiet) { Write-Host ('    {0}' -f [string]$adopt.Note) -ForegroundColor DarkYellow }
            if (-not [string]$adopt.Path) {
                return @{ Ok = $false; Error = ('下载完成后没有找到文件：{0}（{1}）' -f $target, [string]$adopt.Error); Network = $false; Downloaded = $downloaded; Names = $downloadedNames; Any = $downloadedAny }
            }
        }
        # 防御性读取：Invoke-WinstPackageDownload 的每条返回路径都会带 Retried，
        # 这里仍按「可能没有」处理，避免调用方换成别处的结果形状时报错。
        $wasRetried = $false
        if ($dl -is [System.Collections.IDictionary] -and $dl.Contains('Retried')) {
            $wasRetried = [bool]$dl['Retried']
        }
        if ($wasRetried -and -not $Quiet) {
            Write-Host '    多段并发下载失败，已改用单连接重试并成功。' -ForegroundColor DarkYellow
        }
        $check = Test-WinstFileIntegrity -Context $Context -FilePath $target -FileDecl $filePlan['Decl'] `
            -FileUrl $url -SourceVersion $Version
        if (-not $check.Ok) {
            # 刚下载的包校验不通过：删掉坏包并报错（软件源里的包本身有问题）
            Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
            return @{ Ok = $false; Error = ('{0} 校验失败：{1}' -f $name, $check.Error); Network = $false; Downloaded = $downloaded; Names = $downloadedNames; Any = $downloadedAny }
        }
        Set-WinstFilePlanIntegrityFromCheck -FilePlan $filePlan -Check $check
        $downloaded += $target
        $downloadedNames += $name
        $downloadedAny = $true
    }

    return @{ Ok = $true; Error = ''; Network = $false; Downloaded = $downloaded; Names = $downloadedNames; Any = $downloadedAny }
}
