#Requires -Version 5.1

function Save-WinstRepairState {
    <#
    .SYNOPSIS
        ⑧ 落盘：有改动（或台账需要保存）且非预览模式时写 state.json。
    .OUTPUTS
        @{ Saved; Error }
    #>
    param([hashtable]$Context, $State, [bool]$Changed, [bool]$NeedSave, [switch]$DryRun)

    if (-not ($Changed -or $NeedSave)) { return @{ Saved = $false; Error = '' } }
    if ($DryRun) { return @{ Saved = $false; Error = '' } }

    try {
        Save-WinstState -InstallRoot $Context.InstallRoot -State $State
        return @{ Saved = $true; Error = '' }
    } catch {
        return @{ Saved = $false; Error = $_.Exception.Message }
    }
}
