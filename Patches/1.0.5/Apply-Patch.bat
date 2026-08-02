@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
set "PS_EXE=powershell.exe"
where pwsh.exe >nul 2>&1 && set "PS_EXE=pwsh.exe"
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Apply-Patch-And-Run-Closeout.ps1"
exit /b %ERRORLEVEL%
