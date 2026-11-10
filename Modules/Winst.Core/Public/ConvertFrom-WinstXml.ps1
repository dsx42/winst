#Requires -Version 5.1

function ConvertFrom-WinstXml {
    <#
    .SYNOPSIS
        将 XML 文本解析为文档，禁止 DTD 与外部资源解析。
    #>
    param([string]$Text)

    if (-not $Text -or -not $Text.Trim()) { throw 'XML 内容为空' }
    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $textReader = [IO.StringReader]::new($Text)
    $reader = $null
    try {
        $reader = [System.Xml.XmlReader]::Create($textReader, $settings)
        $document = New-Object System.Xml.XmlDocument
        $document.XmlResolver = $null
        $document.Load($reader)
        return ,$document
    } catch {
        throw ('XML 内容无效或包含不允许的 DTD：{0}' -f $_.Exception.Message)
    } finally {
        if ($reader) { $reader.Dispose() }
        $textReader.Dispose()
    }
}
