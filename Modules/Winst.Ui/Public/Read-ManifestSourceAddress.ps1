#Requires -Version 5.1

function Read-ManifestSourceAddress {
    <#
    .SYNOPSIS
        读取一个软件源地址：支持直接粘贴，输入 `c` 从剪贴板读取；直接回车取消。
    .DESCRIPTION
        供「管理软件源」页新建软件源、以及添加失败后重新输入两处共用，
        保证剪贴板这条退路在哪儿都一样。
    .OUTPUTS
        [string] 地址；用户取消时为空串
    #>
    param([string]$Prompt = '  GitHub 仓库或清单地址（输入 c 读取剪贴板；直接回车取消）')

    while ($true) {
        $raw = $null
        try { $raw = Read-Host $Prompt } catch { $raw = $null }
        if ($null -eq $raw -or -not ([string]$raw).Trim()) { return '' }

        $value = ConvertTo-WinstTrimmedInput -Value $raw
        if ($value -ine 'c') { return $value }

        $clip = ''
        try {
            $clip = ConvertTo-WinstTrimmedInput -Value (Get-Clipboard -Raw -ErrorAction Stop)
        } catch {
            try {
                $clip = ConvertTo-WinstTrimmedInput -Value ((Get-Clipboard -ErrorAction Stop) -join '')
            } catch {
                $clip = ''
            }
        }
        if (-not $clip) {
            Write-Host '  剪贴板为空或不可用，请直接输入地址。' -ForegroundColor Yellow
            continue
        }
        Write-Host ('  已从剪贴板读取: {0}' -f $clip) -ForegroundColor DarkGray
        return $clip
    }
}
