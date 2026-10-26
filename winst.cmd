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
rem   - 不要用 start /wait，也不要在本文件里直接跑 powershell——那两种写法都会让
rem     cmd.exe 留在原地等，外层窗口又变成不关闭。
rem
rem conhost.exe 是 Windows 自带的传统控制台宿主（只负责开一个原生控制台窗口），
rem 用它包一层可以保证 winst 的菜单 / 颜色 / %%VAR%% 展开行为与平时双击 cmd 一致，
rem 不受「默认终端」设置影响。用户按 Win+R 或 Win+X 打开的控制台同样不受影响。
rem
rem conhost 不存在（极少见的精简系统）时退回直接起 powershell。
if exist "%SystemRoot%\System32\conhost.exe" (
    start "" "%SystemRoot%\System32\conhost.exe" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0winst.ps1" %*
) else (
    start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0winst.ps1" %*
)
rem
rem 退出码
rem ------
rem 窗口一旦分离，cmd.exe 就不再持有 winst 的退出码，因此本文件固定 exit /b 0。
rem 双击使用不关心退出码；**脚本 / CI 里需要 0 / 1 / 2 / 3 / 4 这些退出码时，
rem 请直接调用 winst.ps1**（powershell -File winst.ps1 ...），它会把真实退出码原样返回。
rem 用本文件取退出码的写法（如 cmd /c winst.cmd update --check）拿到的永远是 0。

exit /b 0
