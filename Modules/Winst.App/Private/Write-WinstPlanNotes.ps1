#Requires -Version 5.1

function Write-WinstPlanNotes {
    <#
    .SYNOPSIS
        说明（notes）段：技术中间结论只在 --verbose 下展示。
    #>
    param($Plan)

    foreach ($note in @(Get-EntryArray -Entry $Plan -Key 'notes')) {
        # 解析过程的中间结论（技术细节）只在 --verbose 下展示，普通输出里只留对用户有用的说明
        if (-not ((Get-WinstState -Name WinstOptions) -and (Get-WinstState -Name WinstOptions).Verbose) -and (Test-WinstTechnicalNote -Note ([string]$note))) { continue }
        Write-Host ('    说明: {0}' -f $note) -ForegroundColor DarkYellow
    }
}
