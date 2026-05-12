@echo off
setlocal
cd /d "%~dp0"

echo Running hard-coded secret/token audit...
rg -n -i --hidden --glob "!.git/*" --glob "!dist/*" "(api[_-]?key|secret|token|bearer|authorization:|password\s*=|PRIVATE KEY|x-api-key|sk-[A-Za-z0-9]{20,}|ghp_[A-Za-z0-9]{20,}|CF_API|R2_)"
if errorlevel 1 (
  echo [OK] No obvious hard-coded secrets found by pattern scan.
) else (
  echo [WARN] Potential secrets found. Review before public push.
)
exit /b 0
