#Requires -Version 5.1

function Assert-WinstYamlPlainScalar {
    param([string]$Value, [int]$Number)

    $unsupported = switch -Regex ($Value) {
        '^$'              { '空键'; break }
        '^["'']'          { '引号标量'; break }
        '^[\[{]'          { '流式集合'; break }
        '^[|>]'           { '多行标量'; break }
        '^!'              { '标签'; break }
        '^&'              { '锚点'; break }
        '^\*'             { '别名'; break }
        '^%'              { '指令'; break }
        '^\?(?:[ \t]|$)'  { '显式映射键'; break }
    }
    if ($unsupported) { throw "YAML 第 $Number 行：暂不支持$unsupported。" }
    if ($Value -match '^[,}\]@`]|^-(?:[ \t]|$)|:(?=[ \t]|$)') {
        throw "YAML 第 $Number 行：语法错误，无引号标量中有非法指示符或键值分隔符。"
    }
}
