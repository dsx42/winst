@echo off
rem winst launcher: double-click to open the interactive menu.
rem
rem -NoProfile        : do not load the user's profile, keeps startup predictable
rem -ExecutionPolicy Bypass : per-process only, nothing is written to the registry
rem %*               : forwards command line arguments, e.g. winst.cmd list --cached
rem
rem 双击时的窗口行为
rem ----------------
rem 双击 .cmd 后由系统创建 cmd.exe 来跑本批处理。若「终端应用程序」的默认值是
rem Windows Terminal（HKCU\Console\%%Startup 下的 DelegationConsole / DelegationTerminal），
rem 这个 cmd.exe 就寄生在一个 Windows Terminal 窗口里。
rem
rem cmd.exe 在退出前会**等待自己启动的子进程结束**。所以只要 powershell 是本批处理
rem 直接跑的（或 start 起的、仍在 cmd.exe 进程树里的）子进程，外层窗口就要一直挂到
rem winst 退出——用户看到的就是「先冒出一个 Windows Terminal，又冒出一个 cmd 控制台，
rem 而第一个窗口不关」。
rem
rem 解决办法：用 start 起一个**自成一体**的 conhost + powershell，本批处理随即 exit /b。
rem cmd.exe 退出后外层窗口立即关闭，winst 在自己的窗口里继续跑。
rem
rem 两个必须注意的地方（改这段之前先看）
rem   - start 的第一项是窗口标题，必须写空标题 ""，否则带空格的路径会被当成标题、
rem     真正的命令反而丢参数；
rem   - 无参数分支不要用 start /wait，也不要在本文件里直接跑 powershell——那两种写法都会让
rem     cmd.exe 留在原地等，外层窗口又变成不关闭；带参数分支必须同步跑（见 :passthrough）。
rem
rem conhost.exe 是 Windows 自带的传统控制台宿主（只负责开一个原生控制台窗口），
rem 用它包一层可以保证 winst 的菜单 / 颜色 / %%VAR%% 展开行为与平时双击 cmd 一致，
rem 不受「默认终端」设置影响。用户按 Win+R 或 Win+X 打开的控制台同样不受影响。
rem
rem conhost 不存在（极少见的精简系统）时退回直接起 powershell。
rem 带参数时不能分离进程：start 起的窗口拿不到 stdout，退出码也固定为 0，
rem 而 winst 自身的版本检测（清单里 winst 条目的 detect 是 cliVersion / winst.cmd -v）
rem 正是靠本文件的标准输出 —— 分离后永远读不到版本号。
if not "%~1"=="" goto :passthrough

if exist "%SystemRoot%\System32\conhost.exe" (
    start "" "%SystemRoot%\System32\conhost.exe" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0winst.ps1" %*
) else (
    start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0winst.ps1" %*
)
rem
rem 双击路径（无参数）窗口是分离的：cmd.exe 不再持有 winst 的退出码，因此这里固定 exit /b 0。

exit /b 0

:passthrough
rem 带参数（脚本 / CI / 版本检测）：同步运行，输出与退出码原样返回给调用方。
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0winst.ps1" %*
exit /b %ERRORLEVEL%
