@echo off
setlocal EnableExtensions
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Configure-Project.ps1"
set "RC=%ERRORLEVEL%"
if "%RC%"=="0" exit /b 0
echo Configuration failed with exit code %RC%.
pause
exit /b %RC%

