@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%.."
set "REPO_ROOT=%CD%"

echo ==========================================================
echo   HeadMotion Mouse - Windows Test Suite Runner
echo ==========================================================
echo.

if exist "%REPO_ROOT%\.venv\Scripts\pytest.exe" (
    "%REPO_ROOT%\.venv\Scripts\pytest.exe" python-prototype\tests\ -v %*
) else (
    pytest python-prototype\tests\ -v %*
)
