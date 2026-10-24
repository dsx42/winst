#Requires -Version 5.1

function Invoke-MenuLoop {
    <#
    .SYNOPSIS
        通用菜单循环：渲染 → 读入 → 分发；统一处理 b（返回上级）与 q（退出）。
    .DESCRIPTION
        -Render      接收 Context 的渲染脚本块
        -Actions     选项 → 脚本块（可声明 param($ctx)）
        -Navigation 属于「打开子菜单」的选项，执行后不追加「按回车返回」
        -NoPauseChoices 执行后同样不追加「按回车返回」，直接重绘菜单——动作自带输入循环
         （如「安装软件」「卸载软件」装/卸完一个回到输入处、直接回车即结束返回）的流程用
    .OUTPUTS
        'quit'（用户退出，含子菜单请求退出）/ 'back'（返回上级）/ $null
    #>
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Render,
        [Parameter(Mandatory = $true)]
        [hashtable]$Context,
        [Parameter(Mandatory = $true)]
        [string[]]$Choices,
        [Parameter(Mandatory = $true)]
        [hashtable]$Actions,
        [string[]]$NavigationChoices = @(),
        [string[]]$NoPauseChoices = @(),
        [switch]$CanGoBack
    )

    while ($true) {
        Clear-ScreenSafe
        & $Render $Context

        $choice = (Read-MenuChoice -Valid $Choices).ToLowerInvariant()

        if ((Test-WinstQuitKey -Text $choice)) { return 'quit' }
        if ($choice -eq 'b') {
            if ($CanGoBack) { return 'back' }
            continue
        }

        $action = $Actions[$choice]
        if (-not $action) { continue }

        # 单个动作抛异常时不能把整个菜单带走：命令行启动时用户只会看到窗口闪一下关掉，
        # 连报错都来不及看。这里拦住、把原因打在屏幕上、等一次回车再回菜单。
        # Ctrl+C 不算：PipelineStoppedException 原样抛出，保持「随时中断」的语义。
        try {
            & $action $Context
        } catch {
            if ($_.Exception -is [System.Management.Automation.PipelineStoppedException]) { throw }

            Write-Host ''
            Write-Host ('  这一步出错了：{0}' -f $_.Exception.Message) -ForegroundColor Red
            if ($_.InvocationInfo -and $_.InvocationInfo.PositionMessage) {
                Write-Host ('  {0}' -f $_.InvocationInfo.PositionMessage) -ForegroundColor DarkGray
            }
            Write-Host '  已取消这一步，没有继续往下做；菜单还在，可以重试或按 q 退出。' -ForegroundColor DarkYellow
            Write-Host ''
            Read-WinstPause -Text '  按回车键返回菜单…'
            continue
        }

        # 子菜单里选择「退出」时，逐层向上传播
        if ((Get-WinstState -Name WinstQuitRequested)) { return 'quit' }

        if ($NavigationChoices -contains $choice) { continue }
        if ($NoPauseChoices -contains $choice) { continue }

        # 流程自己已经「返回」了（用户按回车 / b 退出，没有结果要看）：直接重绘菜单，不多要一次回车
        if ((Get-WinstState -Name WinstSkipMenuPause)) {
            $null = Set-WinstState -Name WinstSkipMenuPause -Value ($false)
            continue
        }

        Write-Host ''
        Read-WinstPause -Text '  按回车键返回菜单…'

    }
}
