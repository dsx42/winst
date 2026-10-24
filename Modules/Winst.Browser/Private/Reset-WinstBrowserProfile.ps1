#Requires -Version 5.1

function Reset-WinstBrowserProfile {
    <#
    .SYNOPSIS
        删掉进程级浏览器 profile（抓取失败 / 超时后调用，防止坏目录被复用），下次抓取自动重建。
    #>
    $dir = (Get-WinstState -Name WinstBrowserProfileDir)
    $null = Set-WinstState -Name WinstBrowserProfileDir -Value ('')
    if ($dir -and (Test-Path -LiteralPath $dir)) {
        Clear-WinstInstallDir -Dir $dir
    }
}
