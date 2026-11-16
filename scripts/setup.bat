@echo off
setlocal enabledelayedexpansion

echo ==========================================================
echo   HeadMotion Mouse - Windows Environment Setup
echo ==========================================================

:: Determine repository root directory
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%.."
set "REPO_ROOT=%CD%"

echo [1/4] Checking Python installation...
where python >nul 2>&1
if %ERRORLEVEL% neq 0 (
    where py >nul 2>&1
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] Python 3.10+ was not found on PATH.
        echo Please install Python from https://www.python.org/ or the Microsoft Store.
        exit /b 1
    ) else (
        set "PY_CMD=py -3"
    )
) else (
    set "PY_CMD=python"
)

%PY_CMD% --version

:: 2. Virtual Environment Setup
echo.
echo [2/4] Initializing Python Virtual Environment (.venv)...
if not exist ".venv\Scripts\python.exe" (
    %PY_CMD% -m venv .venv
    if %ERRORLEVEL% neq 0 (
        echo [ERROR] Failed to create virtual environment.
        exit /b 1
    )
)

echo Installing dependencies from python-prototype\requirements.txt...
.venv\Scripts\python.exe -m pip install --upgrade pip
.venv\Scripts\python.exe -m pip install -r python-prototype\requirements.txt
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Dependency installation failed.
    exit /b 1
)

:: 3. Model Asset Check & Verification
echo.
echo [3/4] Verifying face_landmarker.task model asset...
set "MODEL_DIR=%REPO_ROOT%\python-prototype\models"
set "MODEL_FILE=%MODEL_DIR%\face_landmarker.task"

if not exist "%MODEL_DIR%" (
    mkdir "%MODEL_DIR%"
)

if not exist "%MODEL_FILE%" (
    echo   Fetching MediaPipe face landmarker model...
    curl.exe -L -o "%MODEL_FILE%" "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task"
    if %ERRORLEVEL% neq 0 (
        echo   [WARN] curl failed, attempting download via Python...
        .venv\Scripts\python.exe -c "import urllib.request; urllib.request.urlretrieve('https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task', r'%MODEL_FILE%')"
    )
)

if exist "%MODEL_FILE%" (
    echo   [OK] Model asset present: %MODEL_FILE%
) else (
    echo   [WARN] Model file could not be downloaded automatically.
)

:: 4. Configuration Setup
echo.
echo [4/4] Setting up default configuration...
if not exist "python-prototype\config.json" (
    copy /y "shared\default-settings.json" "python-prototype\config.json" >nul
    echo   [OK] Copied shared\default-settings.json to python-prototype\config.json
) else (
    echo   [OK] python-prototype\config.json already exists.
)

echo.
echo ==========================================================
echo   Windows Setup Complete!
echo   To launch HeadMotion Mouse, run:
echo     scripts\run_python.bat
echo   To run tests, run:
echo     scripts\test.bat
echo ==========================================================
