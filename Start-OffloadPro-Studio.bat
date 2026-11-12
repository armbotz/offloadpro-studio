@echo off
title OffloadPro DIT Studio v4.4.0 - Native Windows Desktop App
if /I "%~1"=="--html" (
    start "" "%~dp0public\index.html"
    exit /b 0
)
if exist "%~dp0OffloadProStudio.exe" (
    start "" "%~dp0OffloadProStudio.exe"
    exit /b 0
)
echo Launching OffloadPro DIT Studio v4.4.0 Native Windows Desktop Application...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Sta -Command "Import-Module '%~dp0modules\OffloadPro\OffloadPro.psd1' -Force; Start-OffloadProApp"
