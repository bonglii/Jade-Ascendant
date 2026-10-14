@echo off
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0publish_ascendant_arsenal.ps1"
exit /b %errorlevel%
