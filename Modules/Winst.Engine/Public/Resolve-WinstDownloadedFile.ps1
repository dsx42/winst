#Requires -Version 5.1

function Resolve-WinstDownloadedFile {
    <#
    .SYNOPSIS
        从本次下载的独立目录中取得期望文件，必要时将唯一的下载产物改名。
    .DESCRIPTION
        优先使用期望文件名。未找到时，排除 .fdownloading 临时文件，将唯一的候选文件改为期望名。
        候选为空或有多个时返回错误，多个候选的错误包含文件名。
    .OUTPUTS
        @{ Path; Note; Error }
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Dir,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $result = @{ Path = ''; Note = ''; Error = '' }
    $target = Join-WinstPath $Dir $Name
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        $result.Path = $target
        return $result
    }

    $candidates = @(Get-ChildItem -LiteralPath $Dir -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike '*.fdownloading' })

    if ($candidates.Count -eq 0) {
        $result.Error = '本次下载没有产生新文件'
        return $result
    }
    if ($candidates.Count -gt 1) {
        $result.Error = ('本次下载产生了多个新文件，无法确定哪一个是目标：{0}' -f (($candidates | ForEach-Object { $_.Name }) -join '、'))
        return $result
    }

    try {
        Move-Item -LiteralPath $candidates[0].FullName -Destination $target -Force -ErrorAction Stop
        $result.Path = $target
        $result.Note = ('下载引擎把文件名写成了「{0}」，已自动改回期望的「{1}」' -f $candidates[0].Name, $Name)
    } catch {
        $result.Error = ('把下载结果改名为「{0}」失败：{1}' -f $Name, $_.Exception.Message)
    }
    return $result
}
