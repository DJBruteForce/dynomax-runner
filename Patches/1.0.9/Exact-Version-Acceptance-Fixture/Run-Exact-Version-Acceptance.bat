@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo ============================================================
echo DYNOMAX CORE 1.0.9 EXACT-VERSION RUNTIME ACCEPTANCE
echo ============================================================
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0Run-Exact-Version-Acceptance.ps1"
set "EXITCODE=%ERRORLEVEL%"

echo.
if "%EXITCODE%"=="0" (
    echo ACCEPTANCE RESULT: PASS
) else (
    echo ACCEPTANCE RESULT: FAIL
)
echo.
echo Review the Results folder printed above.
pause
exit /b %EXITCODE%
