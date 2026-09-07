#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_DIR="${PROJECT_DIR}/dist/ChatGPTTouchBar.app"

swift build -c release --product ChatGPTTouchBar --package-path "${PROJECT_DIR}"
BIN_DIR="$(swift build -c release --product ChatGPTTouchBar --package-path "${PROJECT_DIR}" --show-bin-path)"

rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${BIN_DIR}/ChatGPTTouchBar" "${APP_DIR}/Contents/MacOS/ChatGPTTouchBar"
cp "${PROJECT_DIR}/AppBundle/Info.plist" "${APP_DIR}/Contents/Info.plist"
chmod +x "${APP_DIR}/Contents/MacOS/ChatGPTTouchBar"
/usr/bin/codesign \
  --force \
  --sign - \
  --options runtime \
  --entitlements "${PROJECT_DIR}/AppBundle/ChatGPTTouchBar.entitlements" \
  "${APP_DIR}"

echo "Built ${APP_DIR}"
