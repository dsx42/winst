#Requires -Version 5.1

function Copy-WinstBundleItem {
    <#
    .SYNOPSIS
        校验来源与目标路径后复制一个套件文件或目录，目标参数表示最终位置。
    #>
    param([Parameter(Mandatory = $true)][string]$Source, [Parameter(Mandatory = $true)][string]$Destination)

    Assert-WinstTreeWithoutReparsePoint -Path $Source
    $sourceItem = Get-Item -LiteralPath $Source -Force -ErrorAction Stop
    Assert-WinstSafeWritePath -Path $Destination -Directory:$sourceItem.PSIsContainer
    if (Test-Path -LiteralPath $Destination) { Assert-WinstTreeWithoutReparsePoint -Path $Destination }
    if ($sourceItem.PSIsContainer -and
        ((Test-WinstPathUnderRoot -Path $Destination -Root $Source -AllowEqual) -or
         (Test-WinstPathUnderRoot -Path $Source -Root $Destination -AllowEqual))) {
        throw '套件复制的来源目录与目标目录不能重叠。'
    }

    # 整树预检只执行一次；逐项落位前仍复核路径链，避免每层递归重复扫描整棵子树。
    $pending = New-Object 'System.Collections.Generic.Stack[object]'
    $pending.Push(@{ Source = $sourceItem.FullName; Destination = $Destination })
    while ($pending.Count -gt 0) {
        $current = $pending.Pop()
        Assert-WinstSafeWritePath -Path $current.Source
        $item = Get-Item -LiteralPath $current.Source -Force -ErrorAction Stop
        Assert-WinstSafeWritePath -Path $current.Destination -Directory:$item.PSIsContainer
        if ((Test-Path -LiteralPath $current.Destination) -and
            ([bool](Get-Item -LiteralPath $current.Destination -Force -ErrorAction Stop).PSIsContainer -ne [bool]$item.PSIsContainer)) {
            throw ('套件来源与目标类型不一致：{0}' -f $current.Destination)
        }
        if ($item.PSIsContainer) {
            if (-not (Test-Path -LiteralPath $current.Destination -PathType Container)) {
                $null = New-Item -ItemType Directory -Path $current.Destination -Force -ErrorAction Stop
            }
            foreach ($child in @(Get-ChildItem -LiteralPath $current.Source -Force -ErrorAction Stop)) {
                $pending.Push(@{ Source = $child.FullName; Destination = (Join-WinstPath $current.Destination $child.Name) })
            }
            continue
        }
        $parent = Split-Path -Parent $current.Destination
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
            Assert-WinstSafeWritePath -Path $parent -Directory
            $null = New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop
        }
        Assert-WinstSafeWritePath -Path $current.Destination
        Copy-Item -LiteralPath $current.Source -Destination $current.Destination -Force -ErrorAction Stop
    }
}
