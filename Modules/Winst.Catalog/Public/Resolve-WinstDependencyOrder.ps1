#Requires -Version 5.1

function Resolve-WinstDependencyOrder {
    <#
    .SYNOPSIS
        解析一个软件的传递依赖，返回「依赖在前」的安装顺序（含层级与缺失项）。
    .DESCRIPTION
        从 id 出发按依赖关系后序遍历：先依赖、后本体；同一依赖只出现一次（首次出现的层级为准）。
        依赖 id 在软件源里不存在时记入 Missing——调用方提示后跳过该依赖、继续本体安装，不静默忽略。
    .OUTPUTS
        @{ Ok; Order = @( @{ Id; Level; Via } ); Missing = @( @{ Id; Level; Via } ); Error }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [Parameter(Mandatory = $true)][string]$Id,
        $Plan = $null
    )

    $result = @{ Ok = $false; Order = @(); Missing = @(); Error = '' }
    $index = Get-WinstDependencyIndex -Context $Context
    $deps = New-WinstOrdinalDictionary
    foreach ($key in @($index['Deps'].Keys)) { $deps[$key] = $index['Deps'][$key] }
    # 本体按已选来源覆盖，不能修改进程缓存或合并其它来源的依赖。
    if ($null -ne $Plan) { $deps[$Id] = @(Get-EntryArray -Entry $Plan -Key 'dependencies') }
    if (-not $deps.Contains($Id)) {
        $result.Error = ('软件源里没有找到「{0}」，无法解析它的依赖。' -f $Id)
        return $result
    }

    $state = @{
        Deps        = $deps
        Order       = @()
        Levels      = New-WinstOrdinalDictionary
        Via         = New-WinstOrdinalDictionary
        Visiting    = New-WinstOrdinalDictionary
        Done        = New-WinstOrdinalDictionary
        Missing     = @()
        MissingSeen = New-WinstOrdinalDictionary
    }
    $state['Done'][$Id] = $true   # 本体不入依赖序；依赖成环绕回本体时直接跳过

    foreach ($depId in @($deps[$Id])) {
        if (-not $state['Levels'].Contains($depId)) {
            $state['Levels'][$depId] = 1
            $state['Via'][$depId] = $Id
        }
        Add-WinstDependencyClosure -State $state -Id $depId -Level 1
    }

    $order = @()
    foreach ($depId in @($state['Order'])) {
        $order += @{ Id = $depId; Level = [int]$state['Levels'][$depId]; Via = [string]$state['Via'][$depId] }
    }
    $result.Order = @($order)
    $result.Missing = @($state['Missing'])
    $result.Ok = $true
    return $result
}
