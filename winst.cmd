@echo off
rem winst launcher: double-click to open the interactive menu.
rem
rem -NoProfile        : do not load the user's profile, keeps startup predictable
rem -ExecutionPolicy Bypass : per-process only, nothing is written to the registry
rem %*               : forwards command line arguments, e.g. winst.cmd list --cached
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0winst.ps1" %*
