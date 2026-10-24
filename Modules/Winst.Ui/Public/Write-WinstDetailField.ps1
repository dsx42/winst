#Requires -Version 5.1

function Write-WinstDetailField {
    <#
    .SYNOPSIS
        详情页一行「标签 : 值」；三个详情页（已下载包 / 软件列表 / 已装软件）共用同一缩进与配色。
    .DESCRIPTION
        标签由调用方给出（含补齐空格），保证各页原有对齐不变；只统一「怎么写一行」这件事。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Label,
        [string]$Value = '',
        [string]$Color = 'Gray'
    )

    Write-Host ('    {0}: {1}' -f $Label, $Value) -ForegroundColor $Color
}
