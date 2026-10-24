@echo off
chcp 936 >nul
setlocal EnableExtensions
cd /d "%~dp0"

rem ===========================================================================
rem  winst 构建入口（批处理薄壳）
rem
rem  真正的打包逻辑在 build.ps1（UTF-8 with BOM）。
rem  本文件只做四件事：切到脚本目录、转交给 build.ps1、原样透传参数、回传退出码。
rem  本文件必须是 GBK：cmd.exe 在 chcp 936 下按 OEM 代码页读 .cmd，存成 UTF-8
rem  会让中文提示变成乱码，而批处理本身仍会"看似跑通"。
rem
rem  用法：
rem      build.cmd                    构建并等待回车
rem      build.cmd -NoPause           构建后直接返回
rem      set CI=1 && build.cmd        非交互环境（等价 -NoPause）
rem
rem  发版前改版本号：编辑 Modules\Winst.Core\Public\WinstConstants.ps1
rem  里的 Get-WinstProductVersion，构建只读取、不写回。
rem ===========================================================================

set "WINST_BUILD_SCRIPT=%~dp0build.ps1"

if not exist "%WINST_BUILD_SCRIPT%" (
    echo   [x] 找不到 build.ps1：%WINST_BUILD_SCRIPT%
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%WINST_BUILD_SCRIPT%" %*
exit /b %ERRORLEVEL%