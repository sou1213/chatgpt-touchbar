#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_DIR="${PROJECT_DIR}/dist/ChatGPTTouchBar.app"
INFO_PLIST="${APP_DIR}/Contents/Info.plist"
APP_VERSION="${CHATGPT_TOUCHBAR_VERSION:-}"
BUILD_NUMBER="${CHATGPT_TOUCHBAR_BUILD_NUMBER:-}"
SIGNING_IDENTITY="${CHATGPT_TOUCHBAR_SIGNING_IDENTITY:--}"
ARCHITECTURES="${CHATGPT_TOUCHBAR_ARCHS:-arm64 x86_64}"
ARCHITECTURE_LIST=()
SWIFT_ARCH_ARGS=()

read -r -a ARCHITECTURE_LIST <<< "${ARCHITECTURES}"
for architecture in "${ARCHITECTURE_LIST[@]}"; do
  case "${architecture}" in
    arm64|x86_64)
      SWIFT_ARCH_ARGS+=(--arch "${architecture}")
      ;;
    *)
      echo "Unsupported architecture: ${architecture}" >&2
      exit 1
      ;;
  esac
done

swift build \
  -c release \
  --product ChatGPTTouchBar \
  --package-path "${PROJECT_DIR}" \
  "${SWIFT_ARCH_ARGS[@]}"
BIN_DIR="$(swift build \
  -c release \
  --product ChatGPTTouchBar \
  --package-path "${PROJECT_DIR}" \
  "${SWIFT_ARCH_ARGS[@]}" \
  --show-bin-path)"

rm -rf "${APP_DIR}"
mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"
cp "${BIN_DIR}/ChatGPTTouchBar" "${APP_DIR}/Contents/MacOS/ChatGPTTouchBar"
for architecture in "${ARCHITECTURE_LIST[@]}"; do
  /usr/bin/lipo -verify_arch "${architecture}" \
    "${APP_DIR}/Contents/MacOS/ChatGPTTouchBar"
done
cp "${PROJECT_DIR}/AppBundle/Info.plist" "${INFO_PLIST}"
if [[ -n "${APP_VERSION}" ]]; then
  /usr/libexec/PlistBuddy -c \
    "Set :CFBundleShortVersionString ${APP_VERSION}" "${INFO_PLIST}"
fi
if [[ -n "${BUILD_NUMBER}" ]]; then
  /usr/libexec/PlistBuddy -c \
    "Set :CFBundleVersion ${BUILD_NUMBER}" "${INFO_PLIST}"
fi
"${PROJECT_DIR}/scripts/build_icon.sh" \
  "${PROJECT_DIR}/design/app-icon.png" \
  "${APP_DIR}/Contents/Resources/AppIcon.icns"
cp "${PROJECT_DIR}/LICENSE" "${APP_DIR}/Contents/Resources/LICENSE"
cp -R "${PROJECT_DIR}/LICENSES" "${APP_DIR}/Contents/Resources/LICENSES"
if [[ -d "${PROJECT_DIR}/AppBundle/Resources" ]]; then
  cp -R "${PROJECT_DIR}/AppBundle/Resources/." "${APP_DIR}/Contents/Resources/"
fi
chmod +x "${APP_DIR}/Contents/MacOS/ChatGPTTouchBar"
CODESIGN_ARGS=(
  --force
  --sign "${SIGNING_IDENTITY}"
  --options runtime
  --entitlements "${PROJECT_DIR}/AppBundle/ChatGPTTouchBar.entitlements"
)
if [[ "${SIGNING_IDENTITY}" != "-" ]]; then
  CODESIGN_ARGS+=(--timestamp)
fi
/usr/bin/codesign "${CODESIGN_ARGS[@]}" "${APP_DIR}"
/usr/bin/codesign --verify --deep --strict --verbose=2 "${APP_DIR}"

echo "Built ${APP_DIR}"
