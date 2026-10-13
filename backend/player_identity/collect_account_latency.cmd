@echo off
setlocal
set "JADE_LATENCY_ADB="
for /f "delims=" %%A in ('where adb.exe 2^>nul') do if not defined JADE_LATENCY_ADB set "JADE_LATENCY_ADB=%%A"
if not defined JADE_LATENCY_ADB if exist "D:\Godot\tools\platform-tools\adb.exe" set "JADE_LATENCY_ADB=D:\Godot\tools\platform-tools\adb.exe"
if not defined JADE_LATENCY_ADB if exist "D:\Godot\tools\adb.exe" set "JADE_LATENCY_ADB=D:\Godot\tools\adb.exe"
if not defined JADE_LATENCY_ADB if defined ANDROID_HOME if exist "%ANDROID_HOME%\platform-tools\adb.exe" set "JADE_LATENCY_ADB=%ANDROID_HOME%\platform-tools\adb.exe"
if not defined JADE_LATENCY_ADB (
 echo ADB_NOT_FOUND: add Android platform-tools to PATH and retry.
 exit /b 2
)
"%JADE_LATENCY_ADB%" get-state >nul 2>nul
if errorlevel 1 (
 echo DEVICE_NOT_READY: connect and authorize one Android phone.
 exit /b 3
)
"%JADE_LATENCY_ADB%" logcat -d -v time | findstr /C:"ACCOUNT_LATENCY"
if errorlevel 1 (
 echo NO_ACCOUNT_LATENCY_SAMPLES: install the new export, reproduce login and retry.
 exit /b 4
)
exit /b 0
