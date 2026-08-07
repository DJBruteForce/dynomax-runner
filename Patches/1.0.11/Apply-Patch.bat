@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Apply-Patch.ps1"
set "EXITCODE=%ERRORLEVEL%"
if not "%EXITCODE%"=="0" (
  echo.
  echo DYNOMAX CORE 1.0.11 INSTALL FAILED
  pause
)
exit /b %EXITCODE%
