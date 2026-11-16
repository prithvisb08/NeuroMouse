#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=========================================================="
echo "  HeadMotion Mouse — Unified Test Suite Runner"
echo "=========================================================="

cd "${REPO_ROOT}"

# 1. Run Python Test Suite
echo ""
echo "--- [1/2] RUNNING PYTHON SUITE (pytest) ---"
if [[ -f "${REPO_ROOT}/.venv/bin/pytest" ]]; then
    "${REPO_ROOT}/.venv/bin/pytest" python-prototype/tests/ -v
elif [[ -f "${REPO_ROOT}/.venv/Scripts/pytest.exe" ]]; then
    "${REPO_ROOT}/.venv/Scripts/pytest.exe" python-prototype/tests/ -v
else
    pytest python-prototype/tests/ -v
fi

# 2. Run Native Swift Test Suite
echo ""
echo "--- [2/2] RUNNING NATIVE SWIFT SUITE ---"
OS=$(uname -s)
if [[ "${OS}" == "Darwin" ]] && command -v swift >/dev/null 2>&1; then
    cd "${REPO_ROOT}/macos-app"
    swift run HeadMotionMouseTestsRunner
else
    echo "UNVERIFIED — not executed on this host (Requires macOS with Swift CLI toolchain)"
fi

echo ""
echo "=========================================================="
echo "  ALL VERIFICATION CHECKS COMPLETED"
echo "=========================================================="
