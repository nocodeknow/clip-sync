@echo off
title ClipSync — Uninstall
echo.
echo  ClipSync v2 — Uninstaller
echo  ==========================================
echo.

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERROR] Please right-click and "Run as administrator".
    echo.
    pause & exit /b 1
)

echo  [1/3] Stopping ClipSync...
taskkill /f /im ClipSync.exe >nul 2>&1
echo         Done.
echo.

echo  [2/3] Removing autostart registry entry...
reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "ClipSync" /f >nul 2>&1
echo         Done.
echo.

echo  [3/3] Removing firewall rules...
netsh advfirewall firewall delete rule name="ClipSync54321" >nul 2>&1
netsh advfirewall firewall delete rule name="ClipSync54320" >nul 2>&1
netsh advfirewall firewall delete rule name="ClipSync8080" >nul 2>&1
echo         Done.
echo.

echo  ==========================================
echo  ClipSync completely removed.
echo  You can now delete the ClipSync folder.
echo  ==========================================
echo.
pause
