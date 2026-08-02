@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
set "PS_EXE=powershell.exe"
where pwsh.exe >nul 2>&1 && set "PS_EXE=pwsh.exe"
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Apply-Patch.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" (
    echo.
    echo ============================================================
    echo DYNOMAX 1.0.10 SECRET AND OUTPUT S2 PATCH FAILED
    echo ============================================================
    echo Exit code: %EXIT_CODE%
    echo Review C:\Dynomax\Logs\Patches\1.0.10-S2 and the console output.
    echo.
    pause
)
exit /b %EXIT_CODE%
