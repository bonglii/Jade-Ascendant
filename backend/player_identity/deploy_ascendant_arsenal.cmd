@echo off
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy_ascendant_arsenal.ps1"
exit /b %errorlevel%
