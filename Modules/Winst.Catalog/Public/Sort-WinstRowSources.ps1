#Requires -Version 5.1

function Sort-WinstRowSources {
    <#
    .SYNOPSIS
        按默认优先级重排一行里的软件源（本地清单 → 内置源 → 其它来源按添加顺序；未登记的来源排最后）。
    .DESCRIPTION
        已知本机版本时，优先选版本更高的来源，其次选包内取版且已确认远端文件变化的来源。
        同一档里优先安装来源。安装来源可用但没有更新时，优先切换到明确远端版本最高的来源。
    .OUTPUTS
        重排后的行（`Sources` 第一位即默认要用的来源）
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        $Row,
        [string]$InstalledVersion,
        [hashtable]$Lookup,
        [string]$OriginName = ''
    )

    if (-not $Row) { return $Row }
    $sources = @($Row['Sources'])
    if ($sources.Count -le 1) { return $Row }

    if (-not $Lookup.ContainsKey('Priority')) { $Lookup.Priority = Get-WinstSourcePriority -Context $Context }
    $map = $Lookup.Priority
    # 安装来源没有更新时优先切到明确远端版本最高的来源。
    $best = $null
    if ($OriginName -and ($sources | Where-Object { $_['Ok'] -and $_['Plan'] -and $_['Source'] -ieq $OriginName } | Select-Object -First 1)) {
        $best = Get-WinstRowBestSourceEntry -Row $Row
    }
    $sorted = @($sources | Sort-Object -Property `
        @{ Expression = {
            if (-not $InstalledVersion -or $InstalledVersion -ieq 'unknown') { return 0 }
            if ($_['Ok'] -and $_['Plan']) {
                $snap = Get-WinstUpdateEntrySnapshot -Chosen $_ -InstalledVersion $InstalledVersion
                if ($snap.Cmp -gt 0) { return 0 }
                if ($snap.RemoteFresh -ieq 'changed') { return 1 }
            }
            return 2
        } },
        @{ Expression = {
            if ($OriginName -and $_['Source'] -ieq $OriginName) { return 0 }
            if ($best -and $_['Source'] -ieq $best['Source']) { return 1 }
            return 2
        } },
        @{ Expression = {
            $name = [string]$_['Source']
            if ($name -and $map.ContainsKey($name)) { return [int]$map[$name] }
            return 99
        } },
        @{ Expression = { [string]$_['Source'] } })

    return [ordered]@{
        Id          = $Row['Id']
        Name        = $Row['Name']
        Group       = [string]$Row['Group']
        Sources     = @($sorted)
    }
}
