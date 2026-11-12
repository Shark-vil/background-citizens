@echo off
setlocal

where python.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python was not found in PATH.
    pause
    exit /b 1
)

python.exe "%~dp0tools\build_addon.py"
set "result=%errorlevel%"
pause
exit /b %result%
