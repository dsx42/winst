#Requires -Version 5.1

function Get-WinstRowType {
    <#
    .SYNOPSIS
        取一行（软件源里的条目）的条目类型（小写）；没有可用的来源定义时返回空串。
    .DESCRIPTION
        `download` = 「仅下载软件包」：只有下载 / 更新软件包 / 删除软件包三个操作，
        不安装、不写安装记录、不落地系统项。菜单与 CLI 据此换用对应措辞。
    #>
    param($Row)

    foreach ($entry in @($Row['Sources'])) {
        $typeText = ([string](Get-EntryString -Entry $entry['Plan'] -Key 'type')).Trim().ToLowerInvariant()
        if ($typeText) { return $typeText }
    }
    return ''
}
