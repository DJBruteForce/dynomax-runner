@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
call "%SCRIPT_DIR%Config-And-Setup\05-Framework-Self-Test\Run.bat" %*
exit /b %ERRORLEVEL%
