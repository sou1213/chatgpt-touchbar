#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_ICON="${1:-${PROJECT_DIR}/design/app-icon.png}"
OUTPUT_ICON="${2:-${PROJECT_DIR}/dist/AppIcon.icns}"

if [[ ! -f "${SOURCE_ICON}" ]]; then
  echo "Missing source icon: ${SOURCE_ICON}" >&2
  exit 1
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/ai-touchbar-icon.XXXXXX")"
ICONSET_DIR="${TEMP_DIR}/AppIcon.iconset"
trap 'rm -rf "${TEMP_DIR}"' EXIT

mkdir -p "${ICONSET_DIR}" "$(dirname "${OUTPUT_ICON}")"

make_icon() {
  local size="$1"
  local filename="$2"
  /usr/bin/sips -z "${size}" "${size}" "${SOURCE_ICON}" \
    --out "${ICONSET_DIR}/${filename}" >/dev/null
}

make_icon 16 icon_16x16.png
make_icon 32 icon_16x16@2x.png
make_icon 32 icon_32x32.png
make_icon 64 icon_32x32@2x.png
make_icon 128 icon_128x128.png
make_icon 256 icon_128x128@2x.png
make_icon 256 icon_256x256.png
make_icon 512 icon_256x256@2x.png
make_icon 512 icon_512x512.png
make_icon 1024 icon_512x512@2x.png

/usr/bin/iconutil -c icns "${ICONSET_DIR}" -o "${OUTPUT_ICON}"
echo "Built ${OUTPUT_ICON}"
