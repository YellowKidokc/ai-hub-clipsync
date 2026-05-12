@echo off
setlocal EnableExtensions
cd /d "%~dp0"

echo.
echo ============================================================
echo  AI-HUB: Restore known-good setup into Windows Startup
echo ============================================================

set "SRC=%~dp0"
if "%SRC:~-1%"=="\" set "SRC=%SRC:~0,-1%"
set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "TARGET=%STARTUP%\ai-hub-v2"
set "TTS_HOTKEY=%STARTUP%\nerve-tts-hotkey.ahk"

echo Source : %SRC%
echo Target : %TARGET%
echo.

if not exist "%STARTUP%" (
  echo [FAIL] Startup folder not found: %STARTUP%
  exit /b 1
)

if exist "%TARGET%" (
  echo Removing previous Startup copy...
  rmdir /s /q "%TARGET%"
)

mkdir "%TARGET%" >nul 2>nul

robocopy "%SRC%" "%TARGET%" /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP ^
  /XD ".git" "dist" "__pycache__" ".venv" "Data" "clipsync-bridge\data" "exports" ^
  /XF "restore_known_good_to_startup.bat" "daily_export_to_sync.bat" "audit_for_public_push.bat" >nul
if errorlevel 8 (
  echo [FAIL] Restore copy failed.
  exit /b 1
)

if exist "%SRC%\startup\nerve-tts-hotkey.ahk" (
  copy /Y "%SRC%\startup\nerve-tts-hotkey.ahk" "%TTS_HOTKEY%" >nul
  echo [OK] Updated Startup hotkey script: %TTS_HOTKEY%
) else (
  echo [WARN] startup\nerve-tts-hotkey.ahk not found in repo.
)

echo [OK] Known-good setup restored into Startup.
echo.
echo Next: run AI-HUB from %TARGET%\AI-HUB.ahk
exit /b 0
