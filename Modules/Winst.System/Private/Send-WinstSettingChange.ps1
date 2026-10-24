#Requires -Version 5.1

function Send-WinstSettingChange {
    <#
    .SYNOPSIS
        广播 WM_SETTINGCHANGE，让新启动的进程立即读到更新后的环境变量。
    #>
    if (-not (Get-WinstState -Name WinstSettingChangeReady)) {
        try {
            Add-Type -Namespace WinstNative -Name Methods -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true, CharSet = System.Runtime.InteropServices.CharSet.Auto)]
public static extern System.IntPtr SendMessageTimeout(System.IntPtr hWnd, uint Msg, System.UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out System.UIntPtr lpdwResult);
'@ -ErrorAction Stop
            $null = Set-WinstState -Name WinstSettingChangeReady -Value ($true)
        } catch {
            $null = Set-WinstState -Name WinstSettingChangeReady -Value ($false)
        }
    }
    if (-not (Get-WinstState -Name WinstSettingChangeReady)) { return }
    try {
        $lpdwResult = [UIntPtr]::Zero
        $null = [WinstNative.Methods]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$lpdwResult)
    } catch {
        # 广播失败不影响写入结果
    }
}
