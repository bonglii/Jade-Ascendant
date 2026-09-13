@echo off
setlocal
title Jade Ascendant - Pemeriksaan Game
echo ==================================================
echo JADE ASCENDANT - PEMERIKSAAN GAME
echo Memulai PowerShell. Pesan proses akan tampil di sini.
echo ==================================================
if not exist "%~dp0tools\windows.ps1" (
    echo File tools\windows.ps1 belum ditemukan. Ekstrak hotfix ke folder proyek lama.
    pause
    exit /b 1
)
if "%~1"=="" (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\windows.ps1" -Mode Check
) else (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\windows.ps1" -Mode Check -GodotPath "%~1"
)
set "JADE_EXIT=%ERRORLEVEL%"
if not "%JADE_EXIT%"=="0" echo Proses belum selesai. Baca pesan di atas dan folder artifacts.
pause
exit /b %JADE_EXIT%
