@echo off
chcp 65001 >nul
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0update.ps1"

if errorlevel 1 (
    echo.
    pause
    exit /b 1
)

echo.
pause
