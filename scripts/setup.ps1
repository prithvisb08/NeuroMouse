# HeadMotion Mouse - Windows PowerShell Setup
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")
Set-Location $repoRoot

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  HeadMotion Mouse - Windows Setup (PowerShell)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Python check
Write-Host "[1/4] Checking Python..."
$pythonCmd = "python"
try {
    & $pythonCmd --version
} catch {
    $pythonCmd = "py"
    & $pythonCmd -3 --version
}

# 2. Virtual Environment
Write-Host "`n[2/4] Setting up .venv..."
$venvPython = Join-Path $repoRoot ".venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    & $pythonCmd -m venv .venv
}

Write-Host "Installing dependencies..."
& $venvPython -m pip install --upgrade pip
& $venvPython -m pip install -r python-prototype\requirements.txt

# 3. Model check
Write-Host "`n[3/4] Verifying model asset..."
$modelDir = Join-Path $repoRoot "python-prototype\models"
$modelFile = Join-Path $modelDir "face_landmarker.task"
if (-not (Test-Path $modelDir)) {
    New-Item -ItemType Directory -Path $modelDir -Force | Out-Null
}

if (-not (Test-Path $modelFile)) {
    Write-Host "Downloading MediaPipe model asset..."
    $url = "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task"
    Invoke-WebRequest -Uri $url -OutFile $modelFile
}

if (Test-Path $modelFile) {
    Write-Host "[OK] Model asset ready: $modelFile" -ForegroundColor Green
}

# 4. Config setup
Write-Host "`n[4/4] Setting up config..."
$configFile = Join-Path $repoRoot "python-prototype\config.json"
$sharedConfig = Join-Path $repoRoot "shared\default-settings.json"
if (-not (Test-Path $configFile)) {
    Copy-Item -Path $sharedConfig -Destination $configFile
    Write-Host "[OK] Copied default-settings.json to config.json" -ForegroundColor Green
}

Write-Host "`nSetup Complete! Run: .\scripts\run_python.ps1" -ForegroundColor Green
