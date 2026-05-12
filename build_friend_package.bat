@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

set "SRC=%~dp0"
if "%SRC:~-1%"=="\" set "SRC=%SRC:~0,-1%"
set "DIST=%SRC%\dist\AI-HUB-v2-FRIEND"

echo.
echo ============================================================
echo  AI-HUB v2 - Build Friend Package
echo ============================================================
echo.
echo Source: %SRC%
echo Output: %DIST%
echo.

if exist "%DIST%" (
  echo Removing previous build...
  rmdir /s /q "%DIST%"
)

mkdir "%DIST%" >nul 2>nul

echo Copying app files...
robocopy "%SRC%" "%DIST%" /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP ^
  /XD ".git" "dist" "__pycache__" ".venv" "clipsync-bridge\data" "config" ^
  /XF "build_friend_package.bat" >nul

if errorlevel 8 (
  echo [FAIL] Main copy failed.
  goto :done
)

echo Creating clean config and data folders...
mkdir "%DIST%\config" >nul 2>nul
mkdir "%DIST%\clipsync-bridge\data" >nul 2>nul

copy /Y "%SRC%\config\settings.example.ini" "%DIST%\config\settings.example.ini" >nul

> "%DIST%\config\hotkeys.ini" echo [Hotkeys]
> "%DIST%\config\hotstrings.sav" echo ;
> "%DIST%\config\prompts.json" echo []
> "%DIST%\config\research_links.json" echo []
> "%DIST%\config\storage.json" echo {}
> "%DIST%\clipsync-bridge\data\clips.json" echo []
> "%DIST%\clipsync-bridge\data\prompts.json" echo []
> "%DIST%\clipsync-bridge\data\bookmarks.json" echo []
> "%DIST%\clipsync-bridge\data\window_state.json" echo {}

echo Syncing latest dashboard UIs into package...
if exist "C:\Users\lowes\Desktop\Personal dashboard\prompt_picker.html" copy /Y "C:\Users\lowes\Desktop\Personal dashboard\prompt_picker.html" "%DIST%\clipsync-bridge\prompt_picker.html" >nul
if exist "C:\Users\lowes\Desktop\Personal dashboard\research_links.html" copy /Y "C:\Users\lowes\Desktop\Personal dashboard\research_links.html" "%DIST%\clipsync-bridge\research_links.html" >nul
if exist "C:\Users\lowes\Desktop\Personal dashboard\task-calendar.html" copy /Y "C:\Users\lowes\Desktop\Personal dashboard\task-calendar.html" "%DIST%\modules\task-calendar.html" >nul

echo Copying helper scripts...
copy /Y "%SRC%\config\settings.example.ini" "%DIST%\config\settings.ini" >nul

echo.
echo Build complete.
echo Friend package folder:
echo   %DIST%
echo.
echo Zip that folder and send the ZIP.

:done
echo.
set /p "=Press Enter to close..."
