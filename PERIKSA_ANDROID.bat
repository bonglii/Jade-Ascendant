@echo off
setlocal

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\admob_release_guard.ps1"
set "JADE_GUARD_EXIT=%ERRORLEVEL%"
if not "%JADE_GUARD_EXIT%"=="0" (
    echo AdMob production configuration belum siap. Baca artifacts\admob-release-guard.json.
    pause
    exit /b %JADE_GUARD_EXIT%
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\windows.ps1" -Mode Android
set "JADE_EXIT=%ERRORLEVEL%"
if not "%JADE_EXIT%"=="0" echo Android belum siap. Baca daftar FAIL di atas dan artifacts\android-preflight.json.
pause
exit /b %JADE_EXIT%
