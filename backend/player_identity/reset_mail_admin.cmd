@echo off
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0reset_mail_admin.ps1"
if errorlevel 1 exit /b 1
exit /b 0
