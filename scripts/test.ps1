# HeadMotion Mouse - Windows PowerShell Test Suite Runner
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path (Join-Path $scriptDir "..")
Set-Location $repoRoot

$venvPytest = Join-Path $repoRoot ".venv\Scripts\pytest.exe"

if (Test-Path $venvPytest) {
    & $venvPytest python-prototype\tests\ -v $args
} else {
    pytest python-prototype\tests\ -v $args
}
