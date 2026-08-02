@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
set "PS_EXE=powershell.exe"
where pwsh.exe >nul 2>&1 && set "PS_EXE=pwsh.exe"
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Invoke-PrerequisiteSetup.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"
echo.
if not "%EXIT_CODE%"=="0" echo Task failed with exit code %EXIT_CODE%.
pause
exit /b %EXIT_CODE%
