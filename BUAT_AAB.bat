@echo off
setlocal

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\admob_release_guard.ps1" -RequirePublisher
set "JADE_GUARD_EXIT=%ERRORLEVEL%"
if not "%JADE_GUARD_EXIT%"=="0" (
    echo Build release diblokir karena konfigurasi AdMob/publisher belum valid.
    echo Baca artifacts\admob-release-guard.json.
    pause
    exit /b %JADE_GUARD_EXIT%
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\windows.ps1" -Mode Build
set "JADE_EXIT=%ERRORLEVEL%"
if not "%JADE_EXIT%"=="0" echo Proses belum selesai. Baca pesan di atas dan folder artifacts.
pause
exit /b %JADE_EXIT%
