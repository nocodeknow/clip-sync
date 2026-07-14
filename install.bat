@echo off
title ClipSync — Install
echo.
echo  ClipSync v2 — Installer
echo  ==========================================
echo.

:: Require Administrator (needed for firewall rule only)
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERROR] Please right-click this file and choose
    echo          "Run as administrator".
    echo.
    pause & exit /b 1
)

:: Check EXE exists
if not exist "%~dp0ClipSync.exe" (
    echo  [ERROR] ClipSync.exe not found in this folder.
    echo  Run build.bat first.
    echo.
    pause & exit /b 1
)

echo  [1/3] Registering autostart on login...
:: Adds ClipSync to HKCU Run — starts with Windows for this user, no UAC prompt
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" ^
    /v "ClipSync" /t REG_SZ ^
    /d "\"%~dp0ClipSync.exe\"" /f >nul
if %errorlevel% neq 0 (
    echo  [ERROR] Could not write to registry.
    pause & exit /b 1
)
echo         Done.
echo.

echo  [2/3] Opening firewall ports...
netsh advfirewall firewall delete rule name="ClipSync8080" >nul 2>&1
netsh advfirewall firewall delete rule name="ClipSync54321" >nul 2>&1
netsh advfirewall firewall delete rule name="ClipSync54320" >nul 2>&1
netsh advfirewall firewall add rule name="ClipSync54321" protocol=TCP dir=in localport=54321 action=allow profile=any >nul
netsh advfirewall firewall add rule name="ClipSync54320" protocol=UDP dir=in localport=54320 action=allow profile=any >nul


echo         Done.
echo.

echo  [3/3] Starting ClipSync now...
:: Kill any existing instance first
taskkill /f /im ClipSync.exe >nul 2>&1
timeout /t 1 /nobreak >nul
start "" "%~dp0ClipSync.exe"
timeout /t 2 /nobreak >nul

tasklist /fi "imagename eq ClipSync.exe" 2>nul | find /i "ClipSync.exe" >nul
if %errorlevel% equ 0 (
    echo         Running in background.
) else (
    echo         Started — check clipsync.log if you see issues.
)
echo.

echo  ==========================================
echo  Installation complete!
echo  ClipSync starts automatically every login.
echo  Connect your Android app - it will find this PC automatically.
echo  ==========================================
echo.
pause
