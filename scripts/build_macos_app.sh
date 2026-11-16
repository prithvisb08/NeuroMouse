#!/usr/bin/env bash
set -euo pipefail

# Build and package HeadMotionMouse.app bundle on macOS Apple Silicon
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_DIR="${REPO_ROOT}/macos-app"
OUTPUT_DIR="${REPO_ROOT}/dist"
APP_BUNDLE="${OUTPUT_DIR}/HeadMotionMouse.app"

echo "=========================================================="
echo "  HeadMotion Mouse — Native macOS App Packager"
echo "=========================================================="

cd "${APP_DIR}"

echo "[1/4] Building HeadMotionMouse via Swift Package Manager..."
swift build --product HeadMotionMouse -c release

# Locate release binary
BINARY_PATH="$(swift build --product HeadMotionMouse -c release --show-bin-path)/HeadMotionMouse"
if [[ ! -f "${BINARY_PATH}" ]]; then
    # Fallback to search in .build
    BINARY_PATH=$(find "${APP_DIR}/.build" -name "HeadMotionMouse" -type f -perm +111 | grep -E "release|Release|Products" | head -n 1)
fi

if [[ ! -f "${BINARY_PATH}" ]]; then
    echo "[ERROR] Compiled binary not found at ${BINARY_PATH}"
    exit 1
fi
echo "  Found binary: ${BINARY_PATH}"

echo "[2/4] Assembling .app bundle directory structure..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BINARY_PATH}" "${APP_BUNDLE}/Contents/MacOS/HeadMotionMouse"
chmod +x "${APP_BUNDLE}/Contents/MacOS/HeadMotionMouse"

if [[ -f "${APP_DIR}/Info.plist" ]]; then
    cp "${APP_DIR}/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
else
    echo "[ERROR] Missing Info.plist at ${APP_DIR}/Info.plist"
    exit 1
fi

# Write PkgInfo
echo "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

echo "[3/4] Codesigning HeadMotionMouse.app with designated identifier..."
codesign --force --deep -s - --identifier "com.headmotion.mouse" --requirements '=designated => identifier "com.headmotion.mouse"' "${APP_BUNDLE}"

echo "[4/4] Verifying code signature..."
codesign --verify --deep --strict --verbose=2 "${APP_BUNDLE}"

echo "=========================================================="
echo "  SUCCESS: Packaged application created at:"
echo "  ${APP_BUNDLE}"
echo "=========================================================="
