@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
echo Run-Initial-Validation.bat now executes the project-neutral Dynomax framework self-test.
call "%SCRIPT_DIR%Run-Dynomax-Self-Test.bat" %*
exit /b %ERRORLEVEL%
