@echo off
:: Ensure administrator privileges
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo ========================================================
    echo Error: Administrator privileges are required.
    echo Please right-click this file and select 'Run as administrator'.
    echo ========================================================
    pause
    exit /b 1
)

echo Running USB Repair and Attribute Clear with Elevation...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0repair_script.ps1"
echo.
echo Process complete. Displaying log:
echo ========================================================
type "%~dp0repair_results.txt"
echo.
pause
