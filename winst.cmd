@echo off
rem 双击时用独立窗口打开菜单，启动后立即退出。start 的空标题用于正确传递带空格的路径。
rem 带参数时同步运行，将标准输出和退出码传回调用方。
if not "%~1"=="" goto :passthrough

if exist "%SystemRoot%\System32\conhost.exe" (
    start "" "%SystemRoot%\System32\conhost.exe" "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0winst.ps1" %*
) else (
    start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0winst.ps1" %*
)
exit /b 0

:passthrough
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0winst.ps1" %*
exit /b %ERRORLEVEL%
