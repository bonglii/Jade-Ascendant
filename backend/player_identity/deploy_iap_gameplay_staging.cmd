@echo off
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy_iap_gameplay_staging.ps1"
exit /b %ERRORLEVEL%
