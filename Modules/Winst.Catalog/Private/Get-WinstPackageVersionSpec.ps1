#Requires -Version 5.1

function Get-WinstPackageVersionSpec {
    <#
    .SYNOPSIS
        读取并校验 source.packageVersion：未声明时返回 Ok = $true、Spec = $null。
    .DESCRIPTION
        通用能力：安装包的文件版本信息不可信（如 Chrome 离线安装器的 FileVersion 与包内真实版本不一致）时，
        条目声明 source.packageVersion 让 winst 用 7-Zip 读包内结构派生版本——
          file  （可选，通配）：外层包文件，缺省 = 主包（files[0] 的实际缓存文件）；
          inner （可选，通配）：外层包里需要先取出的内层压缩包（取第一个命中，如 Chrome 的 updater.7z）；
          path  （必填，通配）：最内层压缩包里的条目路径匹配规则（取第一个命中）；
          versionKind / versionBetween（可选）：从命中条目的**文件名**识别版本，与 versionFrom: "file"
                同一套识别器；都未声明时用「第一个像版本号的内容」兜底。
        各软件的包内结构差异（updater.7z / *_chrome_installer.exe …）全部写在清单里，winst 不内置规则。
    .OUTPUTS
        @{ Ok; Spec; Error }   Spec = @{ File; Inner; Path; Kind; Between }（已归一）；未声明时 Spec = $null
    #>
    param($Source)

    $result = @{ Ok = $true; Spec = $null; Error = '' }
    $node = Get-EntryValue -Entry $Source -Key 'packageVersion' -Default $null
    if ($null -eq $node) { return $result }
    if ($node -isnot [System.Collections.IDictionary] -and $node.GetType().Name -ne 'PSCustomObject') {
        $result.Ok = $false
        $result.Error = 'source.packageVersion 要写成对象（可写 file / inner / path / versionKind / versionBetween）'
        return $result
    }

    $allowed = @('file', 'inner', 'path', 'versionKind', 'versionBetween')
    $unknown = @()
    if ($node -is [System.Collections.IDictionary]) {
        foreach ($key in @($node.Keys)) { if ($allowed -notcontains ([string]$key)) { $unknown += [string]$key } }
    } else {
        foreach ($prop in $node.PSObject.Properties) { if ($allowed -notcontains ([string]$prop.Name)) { $unknown += [string]$prop.Name } }
    }
    if ($unknown.Count -gt 0) {
        $result.Ok = $false
        $result.Error = ('source.packageVersion 里有不认识的写法: {0}；可用 {1}' -f ($unknown -join '、'), ($allowed -join ' / '))
        return $result
    }

    $pathText = (Get-EntryString -Entry $node -Key 'path').Trim()
    if (-not $pathText) {
        $result.Ok = $false
        $result.Error = 'source.packageVersion.path 没有填写——要写最内层压缩包里的条目路径通配（如 "*_chrome_installer.exe"）'
        return $result
    }
    $kind = (Get-EntryString -Entry $node -Key 'versionKind').Trim()
    if ($kind -and -not (Get-VersionKindPattern -Kind $kind)) {
        $result.Ok = $false
        $result.Error = ('source.packageVersion.versionKind 写法不认识「{0}」；可用 {1}' -f $kind, ((Get-VersionKindList) -join '、'))
        return $result
    }
    $between = @(Get-EntryArray -Entry $node -Key 'versionBetween')

    $result.Spec = @{
        File    = ((Get-EntryString -Entry $node -Key 'file').Trim())
        Inner   = ((Get-EntryString -Entry $node -Key 'inner').Trim())
        Path    = $pathText
        Kind    = $kind
        Between = $between
    }
    return $result
}
