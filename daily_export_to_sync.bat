@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "EXPORT_ROOT=B:\AI-HUB-SYNC\exports"
set "TODAY=%date:~10,4%-%date:~4,2%-%date:~7,2%"
set "OUT=%EXPORT_ROOT%\%TODAY%"
set "DB_SRC=%~dp0clipsync-bridge\data"
set "CFG_SRC=%~dp0config"

if not exist "B:\AI-HUB-SYNC" (
  echo [FAIL] B:\AI-HUB-SYNC not found.
  exit /b 1
)

mkdir "%OUT%\config" >nul 2>nul
mkdir "%OUT%\databases" >nul 2>nul
mkdir "%OUT%\saved" >nul 2>nul

if exist "%CFG_SRC%" robocopy "%CFG_SRC%" "%OUT%\config" *.ini *.json *.sav /R:1 /W:1 /NFL /NDL /NJH /NJS /NP >nul
if exist "%DB_SRC%" robocopy "%DB_SRC%" "%OUT%\databases" *.* /R:1 /W:1 /NFL /NDL /NJH /NJS /NP >nul

set "STAMP=%date% %time%"
> "%OUT%\restore.ini" echo [restore]
>> "%OUT%\restore.ini" echo date=%TODAY%
>> "%OUT%\restore.ini" echo source=%~dp0
>> "%OUT%\restore.ini" echo startup_target=%%APPDATA%%\Microsoft\Windows\Start Menu\Programs\Startup\ai-hub-v2

> "%OUT%\manifest.json" echo {"date":"%TODAY%","created_at":"%STAMP%","config_dir":"config","databases_dir":"databases","saved_dir":"saved"}

echo [OK] Daily export complete: %OUT%
exit /b 0
