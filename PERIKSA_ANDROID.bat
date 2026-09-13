@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\windows.ps1" -Mode Android
set "JADE_EXIT=%ERRORLEVEL%"
if not "%JADE_EXIT%"=="0" echo Android belum siap. Baca daftar FAIL di atas dan artifacts\android-preflight.json.
pause
exit /b %JADE_EXIT%
