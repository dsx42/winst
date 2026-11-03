#Requires -Version 5.1

function Move-WinstSystemItemOwnership {
    <#
    .SYNOPSIS
        卸载前把共享系统项的清理登记移交给剩余软件，保留最初的环境变量恢复信息。
    #>
    param([hashtable]$Context, [hashtable]$State, [string]$FromId, [string]$ToId,
        [ValidateSet('appliedEnv', 'appliedPath')][string]$Field, $Item)

    $read = Read-WinstState -InstallRoot $Context.InstallRoot
    if ($read.Error -and -not $read.Reset) { throw $read.Error }
    $latest = $read.State
    $target = Get-WinstInstalledApp -State $latest -Id $ToId
    if (-not $target) { throw ('接收共享系统项的软件已不在台账中：{0}' -f $ToId) }
    $key = 'path'
    if ($Field -eq 'appliedEnv') { $key = 'name' }
    $value = Get-EntryString -Entry $Item -Key $key
    $scope = Get-EntryString -Entry $Item -Key 'scope'
    $origin = $Item
    $oldest = [datetime]::MaxValue
    $recipients = @($ToId)

    # 多个软件覆盖过同名变量时，所有剩余登记都保留最初的恢复值，避免恢复到已卸载的软件。
    if ($Field -eq 'appliedEnv') {
        foreach ($ownerId in @($latest.Installed.Keys)) {
            $owner = Get-WinstInstalledApp -State $latest -Id $ownerId
            foreach ($registered in @(Get-EntryArray -Entry $owner -Key $Field)) {
                if ((Get-EntryString -Entry $registered -Key $key) -ine $value -or
                    (Get-EntryString -Entry $registered -Key 'scope') -ine $scope) { continue }
                if ($ownerId -cne $FromId -and $recipients -cnotcontains $ownerId) { $recipients += $ownerId }
                $stamp = [datetime]::MaxValue
                $stampText = Get-EntryString -Entry $owner -Key 'installedAt'
                if ($null -ne (Get-EntryValue -Entry $registered -Key 'existed' -Default $null) -and
                    [datetime]::TryParse($stampText, [ref]$stamp) -and $stamp -lt $oldest) {
                    $oldest = $stamp
                    $origin = $registered
                }
            }
        }
    }

    foreach ($recipientId in $recipients) {
        $entry = Get-WinstInstalledApp -State $latest -Id $recipientId
        $items = @()
        foreach ($registered in @(Get-EntryArray -Entry $entry -Key $Field)) {
            if ((Get-EntryString -Entry $registered -Key $key) -ieq $value -and
                (Get-EntryString -Entry $registered -Key 'scope') -ieq $scope) { continue }
            $items += $registered
        }
        $items += Copy-WinstObjectShallow -InputObject $origin
        $fields = @{}
        $fields[$Field] = $items
        $saved = Update-WinstInstalledAppFields -InstallRoot $Context.InstallRoot -Id $recipientId -Entry $entry -Fields $fields
        Set-WinstInstalledApp -State $State -Id $recipientId -Entry $saved
    }
}
