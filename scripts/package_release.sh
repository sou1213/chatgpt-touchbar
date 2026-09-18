#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLIST_PATH="${PROJECT_DIR}/AppBundle/Info.plist"
DEFAULT_VERSION="$(/usr/libexec/PlistBuddy -c \
  'Print :CFBundleShortVersionString' "${PLIST_PATH}")"
VERSION="${1:-${DEFAULT_VERSION}}"
VERSION="${VERSION#v}"
BUILD_NUMBER="${CHATGPT_TOUCHBAR_BUILD_NUMBER:-$(git -C "${PROJECT_DIR}" rev-list --count HEAD)}"
RELEASE_DIR="${PROJECT_DIR}/dist/release"
NOTARY_LOG_DIR="${PROJECT_DIR}/dist/notarization-logs"
APP_PATH="${PROJECT_DIR}/dist/ChatGPTTouchBar.app"
ARCHIVE_BASENAME="ChatGPTTouchBar-v${VERSION}-macOS"
DMG_PATH="${RELEASE_DIR}/${ARCHIVE_BASENAME}.dmg"
ZIP_PATH="${RELEASE_DIR}/${ARCHIVE_BASENAME}.zip"
CHECKSUM_PATH="${RELEASE_DIR}/SHA256SUMS.txt"
SIGNING_IDENTITY="${CHATGPT_TOUCHBAR_SIGNING_IDENTITY:--}"
NOTARIZE="${CHATGPT_TOUCHBAR_NOTARIZE:-false}"
NOTARY_KEY_PATH="${CHATGPT_TOUCHBAR_NOTARY_KEY_PATH:-}"
NOTARY_KEY_ID="${CHATGPT_TOUCHBAR_NOTARY_KEY_ID:-}"
NOTARY_ISSUER_ID="${CHATGPT_TOUCHBAR_NOTARY_ISSUER_ID:-}"

if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
  echo "Invalid version: ${VERSION}" >&2
  exit 1
fi

if [[ "${NOTARIZE}" == "true" ]]; then
  if [[ "${SIGNING_IDENTITY}" == "-" ]]; then
    echo "Notarized releases require a Developer ID Application identity." >&2
    exit 1
  fi
  for required_value in \
    "${NOTARY_KEY_PATH}" \
    "${NOTARY_KEY_ID}" \
    "${NOTARY_ISSUER_ID}"; do
    if [[ -z "${required_value}" ]]; then
      echo "Notarization credentials are incomplete." >&2
      exit 1
    fi
  done
  if [[ ! -f "${NOTARY_KEY_PATH}" ]]; then
    echo "Notarization key not found: ${NOTARY_KEY_PATH}" >&2
    exit 1
  fi
fi

notarize_artifact() {
  local artifact_path="$1"
  local log_name="$2"
  local response_path="${NOTARY_LOG_DIR}/${log_name}-response.json"
  local log_path="${NOTARY_LOG_DIR}/${log_name}-log.json"
  local submit_status=0
  local submission_id=""

  set +e
  /usr/bin/xcrun notarytool submit \
    --key "${NOTARY_KEY_PATH}" \
    --key-id "${NOTARY_KEY_ID}" \
    --issuer "${NOTARY_ISSUER_ID}" \
    --wait \
    --timeout 30m \
    --output-format json \
    "${artifact_path}" > "${response_path}"
  submit_status=$?
  set -e

  cat "${response_path}"
  submission_id="$(/usr/bin/plutil -extract id raw -o - "${response_path}" 2>/dev/null || true)"
  if [[ -n "${submission_id}" ]]; then
    /usr/bin/xcrun notarytool log \
      --key "${NOTARY_KEY_PATH}" \
      --key-id "${NOTARY_KEY_ID}" \
      --issuer "${NOTARY_ISSUER_ID}" \
      "${submission_id}" \
      "${log_path}" || true
  fi

  if [[ "${submit_status}" -ne 0 ]]; then
    echo "Notarization failed for ${artifact_path}" >&2
    exit "${submit_status}"
  fi
}

CHATGPT_TOUCHBAR_VERSION="${VERSION}" \
CHATGPT_TOUCHBAR_BUILD_NUMBER="${BUILD_NUMBER}" \
CHATGPT_TOUCHBAR_SIGNING_IDENTITY="${SIGNING_IDENTITY}" \
  "${PROJECT_DIR}/scripts/build_app.sh"

rm -rf "${RELEASE_DIR}"
rm -rf "${NOTARY_LOG_DIR}"
mkdir -p "${RELEASE_DIR}" "${NOTARY_LOG_DIR}"

if [[ "${NOTARIZE}" == "true" ]]; then
  NOTARY_ZIP="${NOTARY_LOG_DIR}/ChatGPTTouchBar-notarization.zip"
  /usr/bin/ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${NOTARY_ZIP}"
  notarize_artifact "${NOTARY_ZIP}" "app"
  /usr/bin/xcrun stapler staple "${APP_PATH}"
  /usr/bin/xcrun stapler validate "${APP_PATH}"
  /usr/sbin/spctl --assess --type execute --verbose=2 "${APP_PATH}"
fi

/usr/bin/ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/chatgpt-touchbar-release.XXXXXX")"
trap 'rm -rf "${STAGING_DIR}"' EXIT
/usr/bin/ditto "${APP_PATH}" "${STAGING_DIR}/ChatGPTTouchBar.app"
ln -s /Applications "${STAGING_DIR}/Applications"
cp "${PROJECT_DIR}/LICENSE" "${STAGING_DIR}/LICENSE.txt"

if /usr/sbin/diskutil help image create from 2>&1 \
  | /usr/bin/grep -q -- '--volumeName'; then
  /usr/sbin/diskutil image create from \
    --format UDZO \
    --volumeName "ChatGPT Touch Bar" \
    "${STAGING_DIR}" \
    "${DMG_PATH}"
else
  # macOS 14 GitHub runners still provide the legacy hdiutil interface.
  /usr/bin/hdiutil create \
    -volname "ChatGPT Touch Bar" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"
fi
/usr/bin/hdiutil verify "${DMG_PATH}"

if [[ "${SIGNING_IDENTITY}" != "-" ]]; then
  /usr/bin/codesign \
    --force \
    --sign "${SIGNING_IDENTITY}" \
    --timestamp \
    "${DMG_PATH}"
  /usr/bin/codesign --verify --strict --verbose=2 "${DMG_PATH}"
fi

if [[ "${NOTARIZE}" == "true" ]]; then
  notarize_artifact "${DMG_PATH}" "dmg"
  /usr/bin/xcrun stapler staple "${DMG_PATH}"
  /usr/bin/xcrun stapler validate "${DMG_PATH}"
  /usr/sbin/spctl \
    --assess \
    --type open \
    --context context:primary-signature \
    --verbose=2 \
    "${DMG_PATH}"
fi

(
  cd "${RELEASE_DIR}"
  /usr/bin/shasum -a 256 \
    "$(basename "${DMG_PATH}")" \
    "$(basename "${ZIP_PATH}")" > "$(basename "${CHECKSUM_PATH}")"
)

echo "Packaged release assets in ${RELEASE_DIR}"
