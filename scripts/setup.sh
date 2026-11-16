#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=========================================================="
echo "  HeadMotion Mouse — Environment Setup"
echo "=========================================================="

cd "${REPO_ROOT}"

# 1. Host Architecture Validation
ARCH=$(uname -m)
OS=$(uname -s)
echo "[1/5] Host: ${OS} (${ARCH})"
if [[ "${OS}" != "Darwin" ]]; then
    echo "[WARN] Native macOS components require macOS. Running in cross-platform Python mode."
fi

# 2. Python Virtual Environment Setup
echo "[2/5] Initializing Python Virtual Environment (.venv)..."
if [[ -f ".venv/Scripts/python.exe" ]]; then
    VENV_PY=".venv/Scripts/python.exe"
else
    VENV_PY=".venv/bin/python"
fi

if command -v uv >/dev/null 2>&1; then
    uv venv --python 3.12 .venv || uv venv .venv
    uv pip install --python "${VENV_PY}" -r python-prototype/requirements.txt
else
    if [[ ! -f "${VENV_PY}" ]]; then
        python3 -m venv .venv 2>/dev/null || python -m venv .venv
    fi
    "${VENV_PY}" -m pip install --upgrade pip
    "${VENV_PY}" -m pip install -r python-prototype/requirements.txt
fi

# 3. Model Asset Check & Verification (SHA-256)
echo "[3/5] Verifying face_landmarker.task model asset..."
MODEL_DIR="${REPO_ROOT}/python-prototype/models"
MODEL_FILE="${MODEL_DIR}/face_landmarker.task"
MODEL_SHA256="64184e229b263107bc2b804c6625db1341ff2bb731874b0bcc2fe6544e0bc9ff"

mkdir -p "${MODEL_DIR}"
if [[ ! -f "${MODEL_FILE}" ]]; then
    echo "  Fetching pinned MediaPipe face landmarker model..."
    curl -L -o "${MODEL_FILE}" "https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task"
fi

# Check SHA-256
if command -v shasum >/dev/null 2>&1; then
    ACTUAL_SHA256=$(shasum -a 256 "${MODEL_FILE}" | awk '{print $1}')
elif command -v sha256sum >/dev/null 2>&1; then
    ACTUAL_SHA256=$(sha256sum "${MODEL_FILE}" | awk '{print $1}')
else
    ACTUAL_SHA256=$("${VENV_PY}" -c "import hashlib; print(hashlib.sha256(open(r'${MODEL_FILE}', 'rb').read()).hexdigest())")
fi

if [[ "${ACTUAL_SHA256}" == "${MODEL_SHA256}" ]]; then
    echo "  ✓ Model asset verified: ${MODEL_FILE} (SHA-256 match)"
else
    echo "  [WARN] Checksum mismatch. Expected ${MODEL_SHA256}, got ${ACTUAL_SHA256}"
fi

# 4. Configuration Symlink Setup
echo "[4/5] Linking shared configuration to python-prototype..."
mkdir -p "${REPO_ROOT}/python-prototype"
ln -sf "../shared/default-settings.json" "${REPO_ROOT}/python-prototype/config.json" 2>/dev/null || cp -f "${REPO_ROOT}/shared/default-settings.json" "${REPO_ROOT}/python-prototype/config.json"

# 5. Swift Toolchain Verification
echo "[5/5] Checking Swift toolchain..."
if command -v swift >/dev/null 2>&1; then
    SWIFT_VER=$(swift --version | head -n 1)
    echo "  ✓ Swift toolchain available: ${SWIFT_VER}"
else
    echo "  [INFO] Swift CLI not found. Native app compilation requires Xcode Command Line Tools."
fi

echo "=========================================================="
echo "  Setup Complete! Ready for tracking and tests."
echo "=========================================================="
