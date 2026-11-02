@echo off
setlocal
set "JADE_OWNER_PROJECT=D:\Godot\project\jade-ascendant"
if not "%~1"=="" set "JADE_OWNER_PROJECT=%~1"
set "JADE_OWNER_NODE="
for /f "delims=" %%N in ('where node.exe 2^>nul') do if not defined JADE_OWNER_NODE set "JADE_OWNER_NODE=%%N"
if not defined JADE_OWNER_NODE for %%N in ("D:\Godot\tools\node.exe" "D:\Godot\tools\node\node.exe" "D:\Godot\tools\nodejs\node.exe") do if exist "%%~N" set "JADE_OWNER_NODE=%%~N"
if not defined JADE_OWNER_NODE for /d %%D in ("D:\Godot\tools\node*") do if exist "%%~D\node.exe" set "JADE_OWNER_NODE=%%~D\node.exe"
if not defined JADE_OWNER_NODE (
  echo Node.js tidak ditemukan. Gunakan Node yang dipakai launcher QA sebelumnya.
  pause
  exit /b 1
)
echo INSTALLER=OWNER_SOURCE_R2_PUBLISH_20261102
"%JADE_OWNER_NODE%" "%~dp0publish_owner_source.cjs" --project "%JADE_OWNER_PROJECT%"
set "JADE_OWNER_RESULT=%ERRORLEVEL%"
echo.
if not "%JADE_OWNER_RESULT%"=="0" echo Push belum terkonfirmasi. Simpan output ini; jangan reset atau force-push.
pause
exit /b %JADE_OWNER_RESULT%
