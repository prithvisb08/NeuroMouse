#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "Starting HeadMotion Mouse Python Reference Prototype..."
cd "${REPO_ROOT}"

if [[ -f "${REPO_ROOT}/.venv/bin/python" ]]; then
    PYTHON_EXEC="${REPO_ROOT}/.venv/bin/python"
elif [[ -f "${REPO_ROOT}/.venv/Scripts/python.exe" ]]; then
    PYTHON_EXEC="${REPO_ROOT}/.venv/Scripts/python.exe"
else
    PYTHON_EXEC="python3"
fi

exec "${PYTHON_EXEC}" "${REPO_ROOT}/python-prototype/main.py" "$@"
