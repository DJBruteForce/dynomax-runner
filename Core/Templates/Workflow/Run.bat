@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
set "PS_EXE=powershell.exe"
where pwsh.exe >nul 2>&1 && set "PS_EXE=pwsh.exe"
"%PS_EXE%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%Execute-Workflow.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" (
    echo.
    echo ============================================================
    echo DYNOMAX TASK FAILED
    echo ============================================================
    echo Exit code: %EXIT_CODE%
    echo The console will remain open so the failure can be reviewed.
    echo Check C:\Dynomax\Logs and C:\Dynomax\Exports for diagnostics.
    echo.
    pause
)
exit /b %EXIT_CODE%
