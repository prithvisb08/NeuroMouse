# HeadMotion Mouse - Windows PowerShell Runner
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")
Set-Location $repoRoot

$venvPython = Join-Path $repoRoot ".venv\Scripts\python.exe"
$mainScript = Join-Path $repoRoot "python-prototype\main.py"

if (Test-Path $venvPython) {
    & $venvPython $mainScript $args
} else {
    python $mainScript $args
}
