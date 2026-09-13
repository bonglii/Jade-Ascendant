@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\windows.ps1" -Mode Configure
set "JADE_EXIT=%ERRORLEVEL%"
if not "%JADE_EXIT%"=="0" echo Proses belum selesai. Baca pesan di atas dan folder artifacts.
pause
exit /b %JADE_EXIT%
