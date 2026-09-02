@echo off
chcp 65001 >nul
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0download_books.ps1" %*

if errorlevel 1 (
    echo.
    pause
)
