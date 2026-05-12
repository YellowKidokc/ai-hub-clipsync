@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title AI-HUB Friend Installer

echo.
echo ============================================================
echo  AI-HUB v2 - Install and Troubleshoot
echo ============================================================
echo.

set "FAIL=0"
set "AHKEXE="
set "PYEXE="

where AutoHotkey64.exe >nul 2>nul && set "AHKEXE=AutoHotkey64.exe"
if not defined AHKEXE where AutoHotkey.exe >nul 2>nul && set "AHKEXE=AutoHotkey.exe"
if not defined AHKEXE (
  echo [FAIL] AutoHotkey v2 was not found on PATH.
  echo        Install it from https://www.autohotkey.com/
  set "FAIL=1"
) else (
  echo [OK] AutoHotkey found: %AHKEXE%
)

where python >nul 2>nul && set "PYEXE=python"
if not defined PYEXE (
  echo [FAIL] Python was not found on PATH.
  echo        Install Python 3.10+ and reopen this script.
  set "FAIL=1"
) else (
  for /f "delims=" %%I in ('python --version 2^>^&1') do echo [OK] %%I
)

if not exist "%~dp0config\settings.ini" (
  if exist "%~dp0config\settings.example.ini" (
    copy /Y "%~dp0config\settings.example.ini" "%~dp0config\settings.ini" >nul
    echo [OK] Created config\settings.ini from example.
  ) else (
    echo [FAIL] Missing config\settings.example.ini
    set "FAIL=1"
  )
)

if defined PYEXE (
  echo.
  echo Checking Python package: openpyxl
  python -m pip install --disable-pip-version-check --quiet openpyxl
  if errorlevel 1 (
    echo [WARN] openpyxl install/check failed. AI-HUB may still run, but Excel tools may not.
  ) else (
    echo [OK] openpyxl is available.
  )
)

echo.
echo Creating Startup shortcut...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ws=New-Object -ComObject WScript.Shell; $startup=[Environment]::GetFolderPath('Startup'); $shortcut=$ws.CreateShortcut((Join-Path $startup 'AI-HUB v2.lnk')); $shortcut.TargetPath='%~dp0AI-HUB.ahk'; $shortcut.WorkingDirectory='%~dp0'; $shortcut.IconLocation='%SystemRoot%\System32\shell32.dll,44'; $shortcut.Save()" >nul 2>nul
if errorlevel 1 (
  echo [WARN] Could not create Startup shortcut automatically.
) else (
  echo [OK] Startup shortcut created.
)

echo.
if "%FAIL%"=="0" (
  echo Launching AI-HUB...
  start "" "%~dp0AI-HUB.ahk"
  echo [OK] Launch command sent.
  echo.
  echo Next:
  echo   1. Put your keys into config\settings.ini
  echo   2. Re-run this installer if you want to re-check setup
  echo   3. AI-HUB will now start from the shortcut in Startup
) else (
  echo Setup is not complete yet.
  echo Fix the failed items above, then run this file again.
)

echo.
set /p "=Press Enter to close..."
