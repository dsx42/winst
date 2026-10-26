#Requires -Version 5.1

function Write-WinstPlanDownloadStage {
    <#
    .SYNOPSIS
        ① 下载段：每个文件的地址 / 落位 / 校验，以及安装包保存位置。
    .DESCRIPTION
        -HashRuleFor：由调用方传入「按 hashFrom 取校验规则」的委托（App 层传 Get-WinstHashRule）。
        展示层不直接依赖 Winst.Store，这样 Ui 不需要引用领域模块。
    #>
    param($Plan, [hashtable]$View, [scriptblock]$HashRuleFor = $null)

    $download = Get-EntryValue -Entry $Plan -Key 'download' -Default $null
    $downloadLines = @()
    $fileIndex = 0
    foreach ($file in @(Get-EntryArray -Entry $download -Key 'files')) {
        $fileIndex++
        $role = '附加文件'
        if ($fileIndex -eq 1) { $role = $View.PackageNoun }
        $fileName = Get-EntryString -Entry $file -Key 'name'
        if (-not $fileName) { $fileName = '(未命名)' }
        $downloadLines += ('{0}: {1}' -f $role, $fileName)
        $downloadLines += ('下载地址: {0}' -f (Get-EntryString -Entry $file -Key 'url'))
        $dest = Get-EntryString -Entry $file -Key 'dest'
        if ($dest -and -not $View.IsDownloadType) {
            $destFull = $dest
            if ($View.InstallDir -and -not [IO.Path]::IsPathRooted($dest)) { $destFull = Join-WinstPath $View.InstallDir $dest }
            if (Get-EntryBool -Entry $file -Key 'extract') {
                $downloadLines += ('安装后解压到: {0}' -f $destFull)
            } else {
                $downloadLines += ('安装后放到: {0}' -f $destFull)
            }
        }
        $hashRule = $null
        if ($HashRuleFor) {
            $hashFrom = (Get-EntryString -Entry $file -Key 'hashFrom')
            if (-not $hashFrom) { $hashFrom = 'sha256sums' }
            try { $hashRule = & $HashRuleFor $hashFrom } catch { $hashRule = $null }
        }
        $verifyText = Get-FileVerifyText -File $file -HashRule $hashRule
        if ($verifyText) { $downloadLines += $verifyText }
    }
    if ($View.PkgTarget) { $downloadLines += ('保存到: {0}' -f ($View.PkgTarget + '\')) }
    Write-ResolvedStage -Marker '①' -Label '下载' -Lines $downloadLines
}
