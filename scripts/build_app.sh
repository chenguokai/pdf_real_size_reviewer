#!/bin/zsh

set -euo pipefail

SCRIPT_DIRECTORY="${0:A:h}"
PROJECT_DIRECTORY="${SCRIPT_DIRECTORY:h}"
APP_DIRECTORY="${PROJECT_DIRECTORY}/build/Real Size Previewer.app"
CONTENTS_DIRECTORY="${APP_DIRECTORY}/Contents"

cd "${PROJECT_DIRECTORY}"

swift build -c release --disable-sandbox
BIN_DIRECTORY="$(swift build -c release --disable-sandbox --show-bin-path)"

mkdir -p "${CONTENTS_DIRECTORY}/MacOS"
/usr/bin/ditto "${BIN_DIRECTORY}/RealSizePreviewer" "${CONTENTS_DIRECTORY}/MacOS/RealSizePreviewer"
/usr/bin/ditto "${PROJECT_DIRECTORY}/Resources/Info.plist" "${CONTENTS_DIRECTORY}/Info.plist"
/usr/bin/touch "${APP_DIRECTORY}"

echo "Built ${APP_DIRECTORY}"
