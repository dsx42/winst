#Requires -Version 5.1

function Get-LocalManifestFiles {
    <#
    .SYNOPSIS
        列出全部本地清单文件（按优先级从高到低）。
    .DESCRIPTION
        本地清单 = 与脚本放在一起的清单文件，**不需要添加软件源**，刷新 / 查看都走常规流程：
          ① 脚本同目录 manifest.json（U 盘套件与绿色版的标准位置）
          ② 脚本同目录 manifests\*.json（便于把自己的条目与其它清单分开维护）
          ③ 安装包位置 <pkgDir>\manifests\*.json
        同名条目按上述顺序取靠前者；winst 自己写出的 *.meta.json 与源列表 sources.json 不计入。
    .OUTPUTS
        @( <清单文件绝对路径> )；没有本地清单时返回空数组
    #>
    param([Parameter(Mandatory = $true)][string]$PkgDir)

    # 进程内缓存：每次搜索 / 刷新 / 依赖索引都会列一遍本地清单文件（两次 Get-ChildItem + Sort），
    # 而这一组文件在一次会话里几乎不变（增删清单文件后重开 winst 生效）
    if ((Get-WinstState -Name WinstLocalManifestFilesCache) -and ([string](Get-WinstState -Name WinstLocalManifestFilesCache)['PkgDir'] -ieq $PkgDir)) {
        return @((Get-WinstState -Name WinstLocalManifestFilesCache)['Files'])
    }

    $files = New-Object 'System.Collections.Generic.List[string]'

    if ((Get-WinstState -Name WinstScriptDir)) {
        $main = Join-Path (Get-WinstState -Name WinstScriptDir) 'manifest.json'
        if (Test-Path -LiteralPath $main -PathType Leaf) { $files.Add($main) }

        $scriptManifestDir = Join-Path (Get-WinstState -Name WinstScriptDir) 'manifests'
        if (Test-Path -LiteralPath $scriptManifestDir -PathType Container) {
            foreach ($item in @(Get-ChildItem -LiteralPath $scriptManifestDir -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object -Property Name)) {
                $files.Add([string]$item.FullName)
            }
        }
    }

    if ($PkgDir) {
        $manifestDir = Get-ManifestRootDir -PkgDir $PkgDir
        if (Test-Path -LiteralPath $manifestDir -PathType Container) {
            foreach ($item in @(Get-ChildItem -LiteralPath $manifestDir -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object -Property Name)) {
                if ($item.Name -like '*.meta.json') { continue }
                if ($item.Name -ieq (Get-WinstManifestSourcesFileName)) { continue }
                $files.Add([string]$item.FullName)
            }
        }
    }

    $finalFiles = @(Get-DistinctValues -Values $files.ToArray())
    $null = Set-WinstState -Name WinstLocalManifestFilesCache -Value (@{ PkgDir = $PkgDir; Files = $finalFiles })
    return $finalFiles
}
