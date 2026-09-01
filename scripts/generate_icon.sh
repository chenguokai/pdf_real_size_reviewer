#!/bin/zsh

set -euo pipefail

SCRIPT_DIRECTORY="${0:A:h}"
PROJECT_DIRECTORY="${SCRIPT_DIRECTORY:h}"
ICON_SOURCE="${PROJECT_DIRECTORY}/Resources/AppIcon.svg"
APP_ICON_SET="${PROJECT_DIRECTORY}/Resources/Assets.xcassets/AppIcon.appiconset"
ICON_BUILD_ROOT="$(mktemp -d /private/tmp/real-size-icon.XXXXXX)"

if ! command -v rsvg-convert >/dev/null 2>&1; then
    echo "rsvg-convert is required to regenerate the icon assets (install librsvg)." >&2
    exit 1
fi

render_icon() {
    local pixels="$1"
    local filename="$2"
    rsvg-convert -w "${pixels}" -h "${pixels}" "${ICON_SOURCE}" -o "${APP_ICON_SET}/${filename}"
}

render_icon 16 icon_16x16.png
render_icon 32 icon_16x16@2x.png
render_icon 32 icon_32x32.png
render_icon 64 icon_32x32@2x.png
render_icon 128 icon_128x128.png
render_icon 256 icon_128x128@2x.png
render_icon 256 icon_256x256.png
render_icon 512 icon_256x256@2x.png
render_icon 512 icon_512x512.png
render_icon 1024 icon_512x512@2x.png

mkdir -p "${ICON_BUILD_ROOT}/output"
xcrun actool "${PROJECT_DIRECTORY}/Resources/Assets.xcassets" \
    --compile "${ICON_BUILD_ROOT}/output" \
    --platform macosx \
    --minimum-deployment-target 13.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "${ICON_BUILD_ROOT}/partial-info.plist"

/usr/bin/ditto "${ICON_BUILD_ROOT}/output/AppIcon.icns" "${PROJECT_DIRECTORY}/Resources/AppIcon.icns"

echo "Generated ${PROJECT_DIRECTORY}/Resources/AppIcon.icns"
