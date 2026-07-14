@echo off
title ClipSync — Build
echo.
echo  ClipSync v2 — Build
echo  ==========================================
echo.

:: Check Go is installed
go version >nul 2>&1
if %errorlevel% neq 0 (
    echo  [ERROR] Go not found.
    echo  Install Go from: https://go.dev/dl/
    echo  Then re-run this file.
    echo.
    pause & exit /b 1
)

echo  [1/3] Tidying dependencies...
go mod tidy
if %errorlevel% neq 0 (
    echo  [ERROR] Failed to fetch dependencies. Check internet connection.
    pause & exit /b 1
)
echo         Done.
echo.

echo  [2/3] Compiling ClipSync.exe...
::   -H windowsgui  = no console window
::   -s -w          = strip debug info (smaller binary)
go build -ldflags="-H windowsgui -s -w" -o ClipSync.exe .
if %errorlevel% neq 0 (
    echo  [ERROR] Compilation failed. See error above.
    pause & exit /b 1
)
echo         Done. ClipSync.exe created.
echo.

echo  [3/3] Build complete!
echo  ==========================================
echo  Next step: right-click install.bat and
echo  choose "Run as administrator" to install.
echo  ==========================================
echo.
pause
