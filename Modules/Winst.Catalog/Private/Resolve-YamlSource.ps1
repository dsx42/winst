#Requires -Version 5.1

function Resolve-YamlSource {
    <#
    .SYNOPSIS
        读取 YAML 接口，按清单选择版本和文件。
    #>
    param([hashtable]$Context, $Entry)

    Resolve-DataApiSource -Context $Context -Entry $Entry -ReadResponse ${function:Read-WinstYamlSourceResponse}
}
