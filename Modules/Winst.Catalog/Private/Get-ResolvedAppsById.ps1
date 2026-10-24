#Requires -Version 5.1

function Get-ResolvedAppsById {
    <#
    .SYNOPSIS
        在全部软件源的软件清单（解析锁）中按 id 查找，返回全部命中（含来源名）。
    .DESCRIPTION
        多个软件源之间**没有覆盖关系**，同一 id 可能同时出现在多个源；本函数返回全部命中，
        由调用方（后续的下载 / 安装）在多个命中时让用户选择来源，单一命中时直接使用。
    .OUTPUTS
        @( @{ Source; Name; App } )；未命中返回空数组
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context,
        [string]$Id
    )

    $matches = @()
    if (-not $Id) { return $matches }
    foreach ($source in @(Get-ManifestSourceList -Context $Context)) {
        $name = [string]$source['name']
        if (-not $name) { continue }
        $app = Get-ManifestResolvedApp -PkgDir $Context.PkgDir -Name $name -Id $Id
        if ($app) {
            $matches += [ordered]@{
                Source = $name
                Name   = (Get-EntryString -Entry $app -Key 'name')
                App    = $app
            }
        }
    }
    return @($matches)
}
