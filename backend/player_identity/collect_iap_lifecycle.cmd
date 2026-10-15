@echo off
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0collect_iap_lifecycle.ps1" %*
exit /b %errorlevel%
