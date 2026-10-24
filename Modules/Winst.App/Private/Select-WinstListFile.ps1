#Requires -Version 5.1

function Select-WinstListFile {
    <#
    .SYNOPSIS
        选择一个已有的清单文件：列出 <数据根>\lists\ 下已有的清单，输入编号选择。
    .DESCRIPTION
        输入编号 = 选已有清单；**回车 / b = 返回**（取消）、q = 退出程序。
        - `-NoCreate`：只允许从已有清单里挑（**一键安装 / 制作U盘安装包**用）——不提供「输入文件名新建」，
          输入非编号时重新提示；一个清单都没有时给出「到 高级功能 → 管理X清单 新建」的指引后返回。
        - 不带 `-NoCreate`：输入其它文本 = 按文件名 / 路径解析（编辑清单用）。
    .OUTPUTS
        @{ Ok; Cancelled; Error; Path; Name; Exists }
    #>
    param(
        [Parameter(Mandatory = $true)][hashtable]$Context,
        [switch]$NoCreate
    )

    $kindText = (Get-WinstListKindText)
    $files = @(Get-WinstListFiles -Context $Context)
    $cancel = @{ Ok = $false; Cancelled = $true; Error = ''; Path = ''; Name = ''; Exists = $false }

    # 只挑现成清单时，一个都没有就直接说清去哪建，不提示「输入文件名新建」
    if ($NoCreate -and $files.Count -eq 0) {
        Write-Host ''
        Write-Host ('  lists 目录里还没有{0}。' -f $kindText) -ForegroundColor Yellow
        Write-Host ('  清单目录: {0}' -f (Get-WinstListsDir -Context $Context)) -ForegroundColor DarkGray
        Write-Host ('  可到「高级功能 → 管理{0}」里新建清单后再回来。' -f $kindText) -ForegroundColor DarkGray
        return $cancel
    }

    if ($files.Count -gt 0) {
        Write-Host ''
        Write-Host ('  已有的{0}：' -f $kindText) -ForegroundColor Gray
        Write-WinstListFileRows -Files $files
    }

    Write-Host ''
    if ($files.Count -gt 0) {
        if ($NoCreate) {
            Write-Host '  输入编号选择清单。' -ForegroundColor DarkGray
        } else {
            Write-Host '  输入编号选择已有清单；直接输入文件名新建。' -ForegroundColor DarkGray
        }
    } else {
        Write-Host ('  lists 目录里还没有{0}，可直接输入文件名新建。' -f $kindText) -ForegroundColor DarkGray
    }
    Write-Host '  回车 / b = 返回，q = 退出程序' -ForegroundColor DarkGray

    while ($true) {
        $text = Read-WinstAnswerText -Prompt '  请输入'


        # 回车与 b 同义：返回上一级（不把回车当成「用默认清单」）
        if (-not $text -or $text -ieq 'b') { return $cancel }
        if ((Test-WinstQuitKey -Text $text)) {
            Set-WinstQuit
            return $cancel
        }

        $number = 0
        $isNumber = $false
        if ($files.Count -gt 0) { $isNumber = [int]::TryParse($text, [ref]$number) }
        if ($isNumber) {
            if ($number -ge 1 -and $number -le $files.Count) {
                $path = [string]$files[$number - 1]['Path']
                return @{ Ok = $true; Cancelled = $false; Error = ''; Path = $path; Name = [string]$files[$number - 1]['Name']; Exists = $true }
            }
            # 纯数字但越界：说清范围再问一次，不把它当成文件名去解析
            if ($NoCreate) {
                Write-Host ('  没有这个编号（可选 1 - {0}），请重新输入。' -f $files.Count) -ForegroundColor Yellow
            } else {
                Write-Host ('  没有这个编号（可选 1 - {0}），请重新输入；也可以直接输入新的文件名。' -f $files.Count) -ForegroundColor Yellow
            }
            continue
        }
        # 只挑现成清单时，非编号输入一律按「不是编号」重新询问，不提供新建
        if ($NoCreate) {
            Write-Host ('  「{0}」不是编号，请输入 1 - {1} 之间的数字（回车 / b = 返回）。' -f $text, $files.Count) -ForegroundColor Yellow
            continue
        }
        $resolved = Resolve-WinstListPath -Context $Context -Text $text
        if (-not $resolved.Ok) { return @{ Ok = $false; Cancelled = $false; Error = $resolved.Error; Path = ''; Name = ''; Exists = $false } }
        $name = Split-Path -Leaf $resolved.Path
        return @{ Ok = $true; Cancelled = $false; Error = ''; Path = $resolved.Path; Name = $name; Exists = (Test-Path -LiteralPath $resolved.Path -PathType Leaf) }
    }
}
