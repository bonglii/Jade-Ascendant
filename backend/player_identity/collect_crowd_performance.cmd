@echo off
setlocal
set "JADE_CROWD_ADB="
for /f "delims=" %%A in ('where adb.exe 2^>nul') do if not defined JADE_CROWD_ADB set "JADE_CROWD_ADB=%%A"
if not defined JADE_CROWD_ADB if exist "D:\Godot\tools\platform-tools\adb.exe" set "JADE_CROWD_ADB=D:\Godot\tools\platform-tools\adb.exe"
if not defined JADE_CROWD_ADB if exist "D:\Godot\tools\adb.exe" set "JADE_CROWD_ADB=D:\Godot\tools\adb.exe"
if not defined JADE_CROWD_ADB if defined ANDROID_HOME if exist "%ANDROID_HOME%\platform-tools\adb.exe" set "JADE_CROWD_ADB=%ANDROID_HOME%\platform-tools\adb.exe"
if not defined JADE_CROWD_ADB (
 echo ADB_NOT_FOUND: add Android platform-tools to PATH and retry.
 exit /b 2
)
"%JADE_CROWD_ADB%" get-state >nul 2>nul
if errorlevel 1 (
 echo DEVICE_NOT_READY: connect and authorize one Android phone.
 exit /b 3
)
"%JADE_CROWD_ADB%" logcat -d -v time | findstr /C:"CombatPerf" /C:"CrowdPerf"
if errorlevel 1 (
 echo NO_CROWD_SAMPLES: use a debug Android export, play for at least 24 seconds and retry.
 exit /b 4
)
exit /b 0
