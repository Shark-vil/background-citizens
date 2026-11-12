@echo off
setlocal

where glualint >nul 2>&1
if errorlevel 1 (
    echo ERROR: glualint was not found in PATH.
    pause
    exit /b 1
)

pushd "%~dp0" || exit /b 1
glualint pretty-print lua
set "result=%errorlevel%"
popd

if not "%result%"=="0" echo ERROR: Formatting failed. Some files may already have been formatted.
pause
exit /b %result%
