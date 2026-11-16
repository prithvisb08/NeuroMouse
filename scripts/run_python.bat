@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%.."
set "REPO_ROOT=%CD%"

echo Starting HeadMotion Mouse on Windows...

if exist "%REPO_ROOT%\.venv\Scripts\python.exe" (
    set "PYTHON_EXEC=%REPO_ROOT%\.venv\Scripts\python.exe"
) else (
    set "PYTHON_EXEC=python"
)

"%PYTHON_EXEC%" "%REPO_ROOT%\python-prototype\main.py" %*
